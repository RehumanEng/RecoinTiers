require "google/cloud/firestore"
require "date"
require "logger"

class UpdateUserTiersService
  def initialize
    @firestore = Google::Cloud::Firestore.new(
      project_id: ENV.fetch("FIRESTORE_PROJECT_ID", "rehuman-marketplace"),
      credentials: ENV.fetch("FIRESTORE_CREDENTIALS", "./rehuman-marketplace-firebase-adminsdk-jo14f-d1895b6515.json")
    )
    @logger = Logger.new(STDOUT)
  end

  def run
    log("Starting Update User Tiers Service...")
    process_users
    log("Update User Tiers Service completed successfully.")
  rescue => e
    log("Error during Update User Tiers Service: #{e.message}", :error)
    log(e.backtrace.join("\n"), :error)
  end

  private

  def first_of_last_month
    @first_of_last_month ||= begin
                               today = Date.today

                               first_of_last_month = Date.new(today.year, today.month, 1) << 1
                             end
  end

  def process_users
    users = fetch_users
    users.each do |user_object|
      begin
        update_user_tier(user_object)
      rescue => e
        log("Error processing user #{user_object.document_path}: #{e.message}", :error)
        log(e.backtrace.join("\n"), :error)
      end
    end
  end

  def fetch_users
    @firestore.col("users").run
  end

  def fetch_user_transactions(user_object)
    @firestore.col("transaction_history")
             .where(:user_id, "=", user_object.ref)
             .where(:created_at, :">=", first_of_last_month)
             .run
             .map(&:fields)
  end

  def calculate_tier(total_recoins)
    case total_recoins
    when 0...250
      "Bronze"
    when 251...750
      "Silver"
    else
      "Gold"
    end
  end

  def update_user_tier(user_object)
    transactions = fetch_user_transactions(user_object)
    total_recoins = transactions.sum { |t| t[:amount] || 0 }

    new_tier = calculate_tier(total_recoins)
    # IMPORTANT: The merge option is critical here. Without it, you will wipe the whole document 
    # except for the values specified here
    @firestore.doc(user_object.document_path).set({ tier: new_tier }, merge: true)
    log("Updated tier for user #{user_object.document_path} to #{new_tier} (total recoins: #{total_recoins}).")
  end

  def log(message, level = :info)
    @logger.send(level, "[#{Time.now}] #{message}")
  end
end

UpdateUserTiersService.new.run
