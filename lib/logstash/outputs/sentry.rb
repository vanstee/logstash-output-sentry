# encoding: utf-8
require 'logstash/outputs/base'
require 'logstash/namespace'
 
class LogStash::Outputs::Sentry < LogStash::Outputs::Base
 
  config_name 'sentry'
  milestone 1
 
  config :key, :validate => :string, :required => true
  config :secret, :validate => :string, :required => true
  config :project_id, :validate => :string, :required => true
 
  public
  def register
    require 'net/https'
    require 'uri'
    
    @url = "https://app.getsentry.com/api/#{project_id}/store/"
    @uri = URI.parse(@url)
    @client = Net::HTTP.new(@uri.host, @uri.port)
    @client.use_ssl = true
    @client.verify_mode = OpenSSL::SSL::VERIFY_NONE
 
    @logger.debug("Client", :client => @client.inspect)
  end
 
  public
  def receive(event)
    return unless output?(event)
 
    require 'securerandom'
 
    packet = {
      :event_id => SecureRandom.uuid.gsub('-', ''),
      :timestamp => event['@timestamp'],
      :message => event['message']
    }
 
    packet[:level] = event['[fields][level]']
 
    packet[:platform] = 'logstash'
    packet[:server_name] = event['host']
    packet[:extra] = event['fields'].to_hash
 
    @logger.debug("Sentry packet", :sentry_packet => packet)
 
    auth_header = "Sentry sentry_version=5," +
      "sentry_client=raven_logstash/1.0," +
      "sentry_timestamp=#{event['@timestamp'].to_i}," +
      "sentry_key=#{@key}," +
      "sentry_secret=#{@secret}"
 
    request = Net::HTTP::Post.new(@uri.path)
 
    begin
      request.body = packet.to_json
      request.add_field('X-Sentry-Auth', auth_header)
 
      response = @client.request(request)
 
      @logger.info("Sentry response", :request => request.inspect, :response => response.inspect)
 
      raise unless response.code == '200'
    rescue Exception => e
      @logger.warn("Unhandled exception", :request => request.inspect, :response => response.inspect, :exception => e.inspect)
    end
  end
end

