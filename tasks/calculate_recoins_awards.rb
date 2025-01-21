require "google/cloud/firestore"
require "date"
require "logger"

# Define a struct to store reward information
RecoinAward = Struct.new(:amount, :type, :comment, keyword_init: true)

# Define a module with methods for each reward
module RecoinAwards
  module_function

  def daily_two_thousand
    RecoinAward.new(amount: 5, type: "DailyTwoThousand", comment: "You walked 2,000 steps!")
  end

  def daily_five_thousand
    RecoinAward.new(amount: 1, type: "DailyFiveThousand", comment: "You hit 5,000 steps today!")
  end

  def daily_ten_thousand
    RecoinAward.new(amount: 1, type: "DailyTenThousand", comment: "You hit 10,000 steps today!")
  end

  def monthly_seven_thousand
    RecoinAward.new(amount: 25, type: "MonthlySevenThousand", comment: "You hit 7,000 steps this month!")
  end

  def monthly_twelve_thousand_twice
    RecoinAward.new(amount: 50, type: "MonthlyTwelveThousandTwice", comment: "You hit 12,500 steps twice this month!")
  end

  def monthly_twelve_thousand_five
    RecoinAward.new(amount: 100, type: "MonthlyTwelveThousandFive", comment: "You hit 12,500 steps five times this month!")
  end

  def monthly_streak_twelve_thousand_five
    RecoinAward.new(amount: 500, type: "MonthlyStreakTwelveThousandFive", comment: "You hit a streak of over 12,500 steps for 30 days!")
  end
end

class CalculateRecoinsAwards
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

  def thirty_days_ago
    @thirty_days_ago ||= begin
      thirty = DateTime.now - 30

      Time.new(thirty.year, thirty.month, thirty.day, 0,0)
    end
  end

  def process_users
    users = fetch_users
    beginning_of_month = Date.new(Date.today.year, Date.today.month, 1)

    users.each do |user_object|
      begin
        process_user(user_object, beginning_of_month)
      rescue => e
        log("Error processing user #{user_object.document_path}: #{e.message}", :error)
        log(e.backtrace.join("\n"), :error)
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
    raise e
  end

  def fetch_users
    if ENV['ENV'] == 'test'
      @firestore.col("users").where(:uid, '=', '9VVOlxaUYdgwSVrzud7FSO5Fi6X2').run
    else
      @firestore.col("users").run
    end
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

  def max_at(hash, key, default: nil)
    max = hash.max_by { _1[key] }
    max&.fetch(key, default)
  end

  def calculate_recoins(steps, transactions)
    recoins_to_add = []
    limits = { 7000 => 0, 12_500 => 0 }

    # Daily bonus
    # if steps.any? { |step| step[:step_count] >= 5_000 && step[:date].to_date == Date.today } &&
    #    transactions.none? { |t| t[:parent_id] == RecoinAwards.daily_five_thousand.type && t[:created_at].to_date == Date.today }
    #   recoins_to_add << RecoinAwards.daily_five_thousand.to_h
    # end
    #
    # if steps.any? { |step| step[:step_count] >= 10_000 && step[:date].to_date == Date.today } &&
    #    transactions.none? { |t| t[:parent_id] == RecoinAwards.daily_ten_thousand.type && t[:created_at].to_date == Date.today }
    #   recoins_to_add << RecoinAwards.daily_ten_thousand.to_h
    # end

    daily_transactions_given_today = transactions.count { |t| t[:parent_id] == RecoinAwards.daily_two_thousand.type && t[:created_at].to_date == Date.today }
    todays_steps = steps.filter { |step| step[:date].to_date == Date.today }
    amount_of_two_thousand_steps = (max_at(todays_steps, :step_count, default: 0) / 2000).floor
    amount_of_two_thousand_steps = 20 if amount_of_two_thousand_steps > 20
    daily_amount_to_reward = (amount_of_two_thousand_steps - daily_transactions_given_today)
    daily_amount_to_reward.times { recoins_to_add << RecoinAwards.daily_two_thousand.to_h }

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
      if limits[12_500] >= 5 && transactions.none? { |t| t[:parent_id] == RecoinAwards.monthly_twelve_thousand_five.type }
        recoins_to_add << RecoinAwards.monthly_twelve_thousand_five.to_h
      elsif transactions.none? { |t| t[:parent_id] == RecoinAwards.monthly_twelve_thousand_twice.type }
        recoins_to_add << RecoinAwards.monthly_twelve_thousand_twice.to_h
      end
    end

    transactions_for_thirty_day_streak = transactions.filter { |t| 
    (t[:created_at] > thirty_days_ago || t[:created_at] == thirty_days_ago) && t[:parent_id] == RecoinAwards.monthly_streak_twelve_thousand_five.type 
  }

    streak_start = 
      if transactions_for_thirty_day_streak.any?
        last_award_date = transactions_for_thirty_day_streak.sort_by { |i| i[:created_at] }.last[:created_at]

        Time.new(last_award_date.year, last_award_date.month, last_award_date.day + 1, 0,0)
      else
        thirty_days_ago
      end
    
    steps_for_past_thirty_days = steps.filter { |s| s[:date] >= streak_start }
    
    if steps_for_past_thirty_days.length >= 30 && steps_for_past_thirty_days.all? { |s| s[:step_count] >= 14_000 }
      recoins_to_add << RecoinAwards.monthly_streak_twelve_thousand_five.to_h
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
CalculateRecoinsAwards.new.run unless ENV['ENV'] = 'test'
