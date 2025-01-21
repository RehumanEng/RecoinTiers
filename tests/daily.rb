require_relative './helpers/main'

def multiple_entries_should_not_give_two_thousand
  now = Time.now
  beginning_of_day = Time.new(now.year, now.month, now.day)

  steps = [
    { step_count: 1100, date: beginning_of_day },
    { step_count: 1300, date: beginning_of_day }
  ]

  transactions = []

  service = CalculateRecoinsAwards.new

  result = service.calculate_recoins(steps, transactions)
  result.none? { |r| r[:type] == 'DailyTwoThousand' }
end

def six_thousand_for_today_should_give_three_rewards
  now = Time.now
  beginning_of_day = Time.new(now.year, now.month, now.day)

  steps = [
    { step_count: 6000, date: beginning_of_day },
  ]

  transactions = []

  service = CalculateRecoinsAwards.new

  result = service.calculate_recoins(steps, transactions)
  result.count { |r| r[:type] == 'DailyTwoThousand' } == 3
end

def six_thousand_for_today_should_give_three_rewards_for_two_thousand
  now = Time.now
  beginning_of_day = Time.new(now.year, now.month, now.day)

  steps = [
    { step_count: 6000, date: beginning_of_day },
  ]

  transactions = []

  service = CalculateRecoinsAwards.new

  result = service.calculate_recoins(steps, transactions)
  result.count { |r| r[:type] == 'DailyTwoThousand' } == 3
end

def should_not_give_more_than_twenty_rewards_for_two_thousand
  now = Time.now
  beginning_of_day = Time.new(now.year, now.month, now.day)

  steps = [
    { step_count: 42_000, date: beginning_of_day },
  ]

  transactions = []
  20.times { |i| transactions << { parent_id: 'DailyTwoThousand', created_at: beginning_of_day + (i+1)*20 } }

  service = CalculateRecoinsAwards.new

  result = service.calculate_recoins(steps, transactions)
  result.none? { |r| r[:type] == 'DailyTwoThousand' }
end


puts "Multiple Low Day Entries should not award: #{test_result multiple_entries_should_not_give_two_thousand}"
puts "Six thousand steps should award 3 rewards: #{test_result six_thousand_for_today_should_give_three_rewards_for_two_thousand}"
puts "Should not award more than 20 times: #{test_result should_not_give_more_than_twenty_rewards_for_two_thousand}"
