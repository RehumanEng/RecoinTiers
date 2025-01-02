require 'httparty'

class ShortIOClient
  include HTTParty
  base_uri 'https://api.short.io'

  def initialize(api_key = 'sk_PBJW1DmzY5MoRsP7', domain = 'rewards.rehuman.co.uk')
    @headers = {
      "accept" => 'application/json',
      "content-type" => 'application/json',
      "Authorization" => api_key
    }
    @domain = domain
  end

  def create_link(original_url:, title:)
    options = {
      headers: @headers,
      body: {
        skipQS: false,
        archived: false,
        allowDuplicates: false,
        originalURL: original_url,
        title: title,
        domain: @domain
      }.to_json
    }
    self.class.post('/links', options)
  end

  def delete_link(id)
    options = { headers: @headers }
    self.class.delete("/links/#{id}", options)
  end
end

# Usage example:
# api_client = ShortIOClient.new
# response = api_client.create_link(original_url: 'https://example.com', title: 'Example')
# puts response.body
# delete_response = api_client.delete_link('link_id_here')
# puts delete_response.body
