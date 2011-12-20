module Mailchimp
  class API
    include HTTParty
    format :plain
    default_timeout 30

    attr_accessor :api_key, :timeout, :throws_exceptions

    def initialize(api_key = nil, extra_params = {})
      @api_key = api_key || ENV['MAILCHIMP_API_KEY'] || self.class.api_key
      @default_params = {:apikey => @api_key}.merge(extra_params)
      @throws_exceptions = false
    end

    def api_key=(value)
      @api_key = value
      @default_params = @default_params.merge({:apikey => @api_key})
    end

    def get_exporter
      APIExport.new(@api_key, @default_params)
    end

    def base_api_url
      "https://#{dc_from_api_key}api.mailchimp.com/1.3/?method="
    end

    protected

    def call(method, params = {})
      api_url = base_api_url + method
      params = @default_params.merge(params)
      response = self.class.post(api_url, :body => CGI::escape(params.to_json), :timeout => @timeout)

      begin
        response = JSON.parse(response.body)
      rescue
        response = JSON.parse('['+response.body+']').first
      end

      if @throws_exceptions && response.is_a?(Hash) && response["error"]
        raise "Error from MailChimp API: #{response["error"]} (code #{response["code"]})"
      end

      response
    end

    def method_missing(method, *args)
      method = method.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase } #Thanks for the gsub, Rails
      method = method[0].chr.downcase + method[1..-1].gsub(/aim$/i, 'AIM')
      args = {} unless args.length > 0
      args = args[0] if args.is_a?(Array)
      call(method, args)
    end

    class << self
      attr_accessor :api_key

      def method_missing(sym, *args, &block)
        new(self.api_key).send(sym, *args, &block)
      end
    end

    def dc_from_api_key
      (@api_key.nil? || @api_key.length == 0 || @api_key !~ /-/) ? '' : "#{@api_key.split("-").last}."
    end
  end

  class APIExport < API
    def initialize(api_key = nil, extra_params = {})
      super(api_key, extra_params)
    end

    protected

    def export_api_url
      "http://#{dc_from_api_key}api.mailchimp.com/export/1.0/"
    end

    def call(method, params = {})
      api_url = export_api_url + method + "/"
      params = @default_params.merge(params)
      response = self.class.post(api_url, :body => params, :timeout => @timeout)

      lines = response.body.lines
      if @throws_exceptions
        first_line_object = JSON.parse(lines.first) if lines.first
        raise "Error from MailChimp Export API: #{first_line_object["error"]} (code #{first_line_object["code"]})" if first_line_object.is_a?(Hash) && first_line_object["error"]
      end

      lines
    end
  end
end