# frozen_string_literal: true

# Ruby client for the SMS.ru HTTP API (https://sms.ru/api).
#
#   client = SmsRu.new("YOUR_API_ID")
#   client.deliver("79991234567", "Hello!")
class SmsRu
  BASE_URL = "https://sms.ru"

  # Transport-level exceptions that warrant a retry.
  RETRIABLE = [
    Net::OpenTimeout, Net::ReadTimeout, IOError, EOFError, SocketError,
    Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, OpenSSL::SSL::SSLError
  ].freeze

  # @param api_id  [String]  your SMS.ru API id
  # @param timeout [Integer] open/read timeout in seconds
  # @param test    [Boolean] when true, every deliver defaults to test mode (no charge)
  # @param retries [Integer] retry attempts on transport failure (0 disables; PHP default is 5)
  def initialize(api_id, timeout: 30, test: false, retries: 5)
    @api_id = api_id
    @timeout = timeout
    @test = test
    @retries = retries
  end

  # Sends a message. `to` may be:
  #   - String  -> one number   (text required)
  #   - Array   -> many numbers, same text (text required)
  #   - Hash    -> {number => text} pairs  (text must be omitted)
  def deliver(to, text = nil, from: nil, time: nil, translit: false, test: nil, ip: nil, partner_id: nil)
    params = { from: from, time: time, ip: ip, partner_id: partner_id }.compact
    params[:translit] = 1 if translit
    params[:test] = 1 if test.nil? ? @test : test
    add_recipients(params, to, text)
    SendResult.build(request("/sms/send", **params))
  end

  # Returns the cost and SMS count for a message without sending it.
  def cost(to, text = nil, translit: false)
    params = { to: Array(to).join(","), text: text }.compact
    params[:translit] = 1 if translit
    Cost.build(request("/sms/cost", **params))
  end

  # Delivery status for one id (-> Status) or an Array of ids (-> [Status]).
  def status(sms_id)
    statuses = Status.build_all(request("/sms/status", sms_id: Array(sms_id).join(",")))
    sms_id.is_a?(Array) ? statuses : statuses.first
  end

  # Requests a call-password: SMS.ru calls the number; the last 4 digits of the
  # calling number (returned as `code`) are the authorization code.
  def call(phone)
    Call.build(request("/sms/call", phone: phone.to_s))
  end

  def balance = Balance.build(request("/my/balance"))
  def limit   = Limit.build(request("/my/limit"))
  def free    = Free.build(request("/my/free"))
  def senders = request("/my/senders")["senders"] || []

  # True when the configured api_id is valid.
  def authed?
    request("/auth/check")
    true
  rescue AuthError
    false
  end

  def stoplist  = @stoplist ||= Stoplist.new(method(:request))
  def callbacks = @callbacks ||= Callbacks.new(method(:request))

  private

  def add_recipients(params, to, text)
    if to.is_a?(Hash)
      raise ArgumentError, "do not pass `text` when `to` is a Hash of number => text" unless text.nil?

      to.each { |phone, message| params["multi[#{phone}]"] = message }
    else
      raise ArgumentError, "`text` is required" if text.nil?

      params[:to] = Array(to).join(",")
      params[:msg] = text
    end
  end

  def request(path, **params)
    params[:api_id] = @api_id unless params[:api_id] == "none"
    uri = URI("#{BASE_URL}#{path}?json=1")
    perform(uri, URI.encode_www_form(params))
  end

  def perform(uri, body)
    attempts = 0
    begin
      attempts += 1
      response = http(uri).post(uri.request_uri, body, "Content-Type" => "application/x-www-form-urlencoded")
      parse(response.body)
    rescue *RETRIABLE => e
      retry if attempts <= @retries

      raise ConnectionError, "Cannot reach SMS.ru: #{e.message}"
    end
  end

  def http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = @timeout
    http.read_timeout = @timeout
    http
  end

  def parse(raw)
    data = JSON.parse(raw.to_s)
    raise ConnectionError, "Malformed response from SMS.ru" unless data.is_a?(Hash) && data["status"]
    return data if data["status"] == "OK"

    raise error_for(data)
  rescue JSON::ParserError
    raise ConnectionError, "Invalid JSON from SMS.ru"
  end

  def error_for(data)
    code = data["status_code"]
    text = data["status_text"] || "SMS.ru returned an error"
    error_class(code).new(code: code, text: text)
  end

  def error_class(code)
    case code
    when 200, 300, 301, 302 then AuthError
    when 201 then InsufficientFundsError
    else ResponseError
    end
  end
end
