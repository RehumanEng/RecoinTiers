require "google/cloud/firestore"
require "date"
require "logger"

# Define a struct to store reward information
RecoinAward = Struct.new(:amount, :type, :comment, keyword_init: true)

# Define a module with methods for each reward
module RecoinAwards
  module_function

  def daily_ten_thousand
    RecoinAward.new(amount: 2, type: "DailyTenThousand", comment: "You hit 10,000 steps today!")
  end

  def monthly_seven_thousand
    RecoinAward.new(amount: 3, type: "MonthlySevenThousand", comment: "You hit 7000 steps this month!")
  end

  def twelve_thousand_twice
    RecoinAward.new(amount: 16, type: "MonthlyTwelveThousandTwice", comment: "You hit 12,500 steps twice this month!")
  end

  def twelve_thousand_five
    RecoinAward.new(amount: 40, type: "MonthlyTwelveThousandFive", comment: "You hit 12,500 steps five times this month!")
  end
end

class CalulateRecoinsAwards
  def initialize
    @firestore = Google::Cloud::Firestore.new(
      project_id: ENV.fetch("FIRESTORE_PROJECT_ID", "rehuman-marketplace"),
      credentials: ENV.fetch("FIRESTORE_CREDENTIALS", "./rehuman-marketplace-firebase-adminsdk-jo14f-d1895b6515.json")
    )
    @logger = Logger.new(STDOUT)
  end

  def run
    log("Starting Recoins Job...")
    process_users
    log("Recoins Job completed successfully.")
  rescue => e
    log("Error during Recoins Job: #{e.message}", :error)
    log(e.backtrace.join("\n"), :error)
  end

  private

  def process_users
    users = fetch_users
    beginning_of_month = Date.new(Date.today.year, Date.today.month, 1)

    users.each do |user_object|
      begin
        process_user(user_object, beginning_of_month)
      rescue => e
        log("Error processing user #{user_object.document_path}: #{e.message}", :error)
        log(e.backtrace.join("\n"), :error)
        # Continue to the next user
      end
    end
  end

  def process_user(user_object, beginning_of_month)
    user = user_object.fields
    steps = fetch_steps(user_object, beginning_of_month)
    transactions = fetch_transactions(user_object, beginning_of_month)
    recoins_to_add = calculate_recoins(steps, transactions)

    update_user_balance(user_object, user, recoins_to_add)
    record_transactions(user_object, recoins_to_add)
  rescue => e
    raise e # Optional: re-raise the error if you want it to propagate to process_users
  end

  def fetch_users
    @firestore.col("users").run
  end

  def fetch_steps(user_object, beginning_of_month)
    @firestore.col("users_steps")
             .where(:user_id, "=", user_object.ref)
             .where(:date, :">=", beginning_of_month)
             .run
             .map(&:fields)
  end

  def fetch_transactions(user_object, beginning_of_month)
    @firestore.col("transaction_history")
             .where(:user_id, "=", user_object.ref)
             .where(:created_at, :">=", beginning_of_month)
             .run
             .map(&:fields)
  end

  def calculate_recoins(steps, transactions)
    recoins_to_add = []
    limits = { 7000 => 0, 12_500 => 0 }

    # Daily bonus
    if steps.any? { |step| step[:step_count] >= 10_000 && step[:date].to_date == Date.today } &&
       transactions.none? { |t| t[:parent_id] == RecoinAwards.daily_ten_thousand.type && t[:created_at].to_date == Date.today }
      recoins_to_add << RecoinAwards.daily_ten_thousand.to_h
    end

    # Step count limits
    steps.each do |step|
      limits.each_key do |limit|
        limits[limit] += 1 if step[:step_count] >= limit
      end
    end

    # Monthly bonuses
    if limits[7000] >= 1 && transactions.none? { |t| t[:parent_id] == RecoinAwards.monthly_seven_thousand.type }
      recoins_to_add << RecoinAwards.monthly_seven_thousand.to_h
    end

    if limits[12_500] >= 2
      if limits[12_500] >= 5 && transactions.none? { |t| t[:parent_id] == RecoinAwards.twelve_thousand_five.type }
        recoins_to_add << RecoinAwards.twelve_thousand_five.to_h
      elsif transactions.none? { |t| t[:parent_id] == RecoinAwards.twelve_thousand_twice.type }
        recoins_to_add << RecoinAwards.twelve_thousand_twice.to_h
      end
    end

    recoins_to_add
  end

  def update_user_balance(user_object, user, recoins_to_add)
    new_balance = (user[:recoin_balance] || 0) + recoins_to_add.sum { |r| r[:amount] }
    @firestore.doc(user_object.document_path).set({ recoin_balance: new_balance }, merge: true)
    log("Updated balance for user #{user_object.document_path} to #{new_balance}.")
  end

  def record_transactions(user_object, recoins_to_add)
    history = @firestore.col("transaction_history")
    recoins_to_add.each do |transaction|
      history.doc.set({
        user_id: user_object.ref,
        amount: transaction[:amount],
        parent_type: "StepChallenge",
        parent_id: transaction[:type],
        comment: transaction[:comment],
        created_at: DateTime.now
      })
      log("Recorded transaction: #{transaction[:type]} for user #{user_object.document_path}.")
    end
  end

  def log(message, level = :info)
    @logger.send(level, "[#{Time.now}] #{message}")
  end
end

# To execute the job
CalulateRecoinsAwards.new.run
