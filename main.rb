require "google/cloud/firestore"
require 'date'

@firestore = Google::Cloud::Firestore.new(
  project_id: "rehuman-marketplace",
  credentials: "./rehuman-marketplace-firebase-adminsdk-jo14f-d1895b6515.json"
)

def recoins_to_add_for_steps
  users = @firestore.col('users').run
  beginning_of_month = Date.new(Date.today.year, Date.today.month, 1)

  users.map do |user_object|
    recoins_to_add = []
    limits = {
      7000 => 0,
      12_500 => 0,
    }

    user = user_object.fields
    steps_object = @firestore.col('users_steps').where(:user_id, '=', user_object.ref).where(:date, :>=, beginning_of_month).run
    steps = steps_object.map(&:fields)
    transactions = @firestore.col('transaction_history').where(:user_id, '=', user_object.ref).where(:created_at, :>=, beginning_of_month).run.map(&:fields)

    if steps.any? { |step| step[:step_count] >= 10_000 && step[:date].to_date == Date.today } &&  transactions.none? { |t| t[:parent_id] == 'DailyTenThousand' && t[:created_at].to_date == Date.today }
      recoins_to_add << { amount: 2, type: 'DailyTenThousand', comment: 'You hit 10,000 steps today!' }
    end

    limits.each do |limit, count|
      steps.each do |step|
        limits[limit] += 1 if step[:step_count] >= limit
      end
    end

    if limits[7000] >= 1 && transactions.none? { |t| t[:parent_id] == 'MonthlySevenThousand' }
      recoins_to_add << { amount: 3, type: 'MonthlySevenThousand', comment: 'You hit 7000 steps this month!' }
    end

    if limits[12_500] >= 2 && transactions.none? { |t| t[:parent_id] == 'MonthlyTwelveThousandTwice' }
      if limits[12_500] >= 5 && transactions.none? { |t| t[:parent_id] == 'MonthlyTwelveThousandFive' }
        recoins_to_add << { amount: 40, type: 'MonthlyTwelveThousandFive', comment: 'You hit 12,500 steps five times this month!' }
      else
        recoins_to_add << { amount: 16, type: 'MonthlyTwelveThousandTwice', comment: 'You hit 12,500 steps twice this month!' }
      end
    end

    recoin_amount = (user[:recoin_balance] || 0) + recoins_to_add.sum { |r| r[:amount] }
    history = @firestore.col("transaction_history")

    @firestore.doc(user_object.document_path).set({ recoin_balance: recoin_amount }, merge: true)
    recoins_to_add.each do |transaction|
      history.doc.set({ 
        user_id: user_object.ref,
        amount: transaction[:amount],
        parent_type: 'StepChallenge',
        parent_id: transaction[:type],
        comment: transaction[:comment],
        created_at:  DateTime.now
      })
    end

    [user, recoins_to_add, limits]
  end
end