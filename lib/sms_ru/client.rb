# frozen_string_literal: true

# Ruby client for the SMS.ru HTTP API (https://sms.ru/api).
#
#   client = SmsRu.new("YOUR_API_ID")
#   client.deliver("79991234567", "Hello!")
class SmsRu
  # Base URL of the SMS.ru HTTP API.
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

  # Sends a message.
  #
  # @param to [String, Array<String>, Hash{String => String}] recipient(s):
  #   a String for one number, an Array for the same text to many numbers, or a
  #   Hash of `number => text` pairs for a different text per number.
  # @param text [String, nil] the message text; required for the String/Array
  #   forms, must be omitted for the Hash form
  # @param from [String, nil] an approved sender name
  # @param time [Integer, nil] schedule the send at this UNIX timestamp
  # @param ttl [Integer, nil] message lifetime in minutes (1–1440); undelivered
  #   messages are discarded after this period
  # @param daytime [Boolean] when true, defer night-time sends to the recipient's daytime
  # @param translit [Boolean] transliterate Cyrillic to Latin
  # @param test [Boolean, nil] override the client's global test mode for this call
  # @param ip [String, nil] the end-user IP (anti-fraud for auth codes)
  # @param partner_id [Integer, nil] partner program id
  # @return [SmsRu::SendResult]
  # @raise [ArgumentError] if `text` is missing (String/Array) or given (Hash)
  # @raise [SmsRu::ResponseError] if SMS.ru rejects the whole request
  # @example Send one message
  #   client.deliver("79991234567", "Hello!")
  # @example Per-number text
  #   client.deliver({ "79991234567" => "Hi Alice", "79991234568" => "Hi Bob" })
  def deliver(to, text = nil, from: nil, time: nil, ttl: nil, daytime: false,
              translit: false, test: nil, ip: nil, partner_id: nil)
    params = { from:, time:, ttl:, ip:, partner_id: }.compact
    params[:translit] = 1 if translit
    params[:daytime] = 1 if daytime
    params[:test] = 1 if test.nil? ? @test : test
    add_recipients(params, to, text)
    SendResult.build(request("/sms/send", **params))
  end

  # Returns the cost and SMS count for a message without sending it.
  #
  # @param to [String, Array<String>] recipient(s)
  # @param text [String, nil] the message text (omit for the price of one SMS)
  # @param translit [Boolean] transliterate Cyrillic to Latin
  # @return [SmsRu::Cost]
  # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
  # @example
  #   client.cost("79991234567", "How much?").total_cost
  def cost(to, text = nil, translit: false)
    params = { to: Array(to).join(","), text: text }.compact
    params[:translit] = 1 if translit
    Cost.build(request("/sms/cost", **params))
  end

  # Delivery status for one id or an Array of ids.
  #
  # @param sms_id [String, Array<String>] one message id or an Array of ids
  # @return [SmsRu::Status, Array<SmsRu::Status>] a single Status for a String
  #   argument, or an Array of Status for an Array argument
  # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
  def status(sms_id)
    statuses = Status.build_all(request("/sms/status", sms_id: Array(sms_id).join(",")))
    sms_id.is_a?(Array) ? statuses : statuses.first
  end

  # Requests a flash-call verification: SMS.ru calls the number; the last 4
  # digits of the calling number (returned as `code`) are the code the user enters.
  #
  # @param phone [String, Integer] the number to call
  # @param ip [String] the end-user IP (anti-fraud); "-1" for manual/local requests
  # @param partner_id [Integer, nil] partner program id
  # @return [SmsRu::Call]
  # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
  def call(phone, ip: "-1", partner_id: nil)
    Call.build(request("/code/call", **{ phone: phone.to_s, ip:, partner_id: }.compact))
  end

  # @return [SmsRu::My] the account-info sub-resource (balance, limit, free_limit, senders)
  def my = @my ||= My.new(method(:request))

  # @return [SmsRu::Auth] the authentication sub-resource
  def auth = @auth ||= Auth.new(method(:request))

  # @return [SmsRu::Stoplist] the stoplist sub-resource
  def stoplist = @stoplist ||= Stoplist.new(method(:request))

  # @return [SmsRu::Callbacks] the callbacks sub-resource
  def callbacks = @callbacks ||= Callbacks.new(method(:request))

  # @return [SmsRu::CallCheck] the call-check (incoming-call auth) sub-resource
  def callcheck = @callcheck ||= CallCheck.new(method(:request))

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
