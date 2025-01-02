require "logger"
require "google/cloud/firestore"
require "json"
require_relative "../lib/short_io_client"

class GenerateAffiliateLinks
  LINKS = {
    "Oura Ring" => {
      id: 'czLx4lfPFTzacUTVpxnh',
      rewards: {
        Bronze: "https://partnerships.ouraring.com/G42K59Q/GTSC3/?sub1=five",
        Silver: "https://partnerships.ouraring.com/G42K59Q/GTSC3/?sub1=8",
        Gold: "https://partnerships.ouraring.com/G42K59Q/GTSC3/?sub1=tenten",
      }
    }
  }.freeze

  def initialize
    @firestore = Google::Cloud::Firestore.new(
      project_id: ENV.fetch("FIRESTORE_PROJECT_ID", "rehuman-marketplace"),
      credentials: ENV.fetch("FIRESTORE_CREDENTIALS", "./rehuman-marketplace-firebase-adminsdk-jo14f-d1895b6515.json")
    )
    @logger = Logger.new($stdout)
    @api_client = ShortIOClient.new
  end

  def call
    LINKS.each do |brand, links|
      begin
        reward_links = generate_short_links(brand, links[:rewards])
        update_firestore(links[:id], reward_links)
      rescue StandardError => e
        @logger.error("Error processing brand '#{brand}': #{e.message}")
      end
    end
  end

  private

  def generate_short_links(brand, rewards)
    rewards.each_with_object({}) do |(tier, link), reward_links|
      response = @api_client.create_link(original_url: link, title: "#{brand} #{tier}")

      if response.success?
        parsed_response = JSON.parse(response.body)
        reward_links[tier] = {
          short_url: parsed_response['shortURL'],
          link_id: parsed_response['id']
        }
      else
        @logger.warn("Failed to create short link for #{brand} #{tier}: #{response.error_message}")
      end
    end
  end

  def update_firestore(doc_id, reward_links)
    doc = @firestore.doc("marketplace_rewards/#{doc_id}")

    data = {
      bronze_link: reward_links.dig(:Bronze, :short_url),
      bronze_link_id: reward_links.dig(:Bronze, :link_id),
      silver_link: reward_links.dig(:Silver, :short_url),
      silver_link_id: reward_links.dig(:Silver, :link_id),
      gold_link: reward_links.dig(:Gold, :short_url),
      gold_link_id: reward_links.dig(:Gold, :link_id)
    }.compact

    doc.set(data, merge: true)
    @logger.info("Updated Firestore for document ID '#{doc_id}' with data: #{data}")
  end
end

GenerateAffiliateLinks.new.call