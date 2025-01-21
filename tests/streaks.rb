require_relative './helpers/main'

def thirty_day_streak_works
  steps = []
  times = generate_time_array(CalculateRecoinsAwards.new.thirty_days_ago)
  times.each do |time|
    steps << { step_count: 15_000, date: time }
  end

  transactions = []

  service = CalculateRecoinsAwards.new

  result = service.calculate_recoins(steps, transactions)
  result.any? { |r| r[:type] == 'MonthlyStreakTwelveThousandFive' }
end

def thirty_day_streak_should_not_be_given_yet_as_already_awarded
  steps = []
  times = generate_time_array(CalculateRecoinsAwards.new.thirty_days_ago)
  times.each do |time|
    steps << { step_count: 15_000, date: time }
  end

  transactions = [
    { parent_id: 'MonthlyStreakTwelveThousandFive', created_at: times[1] },
  ]

  service = CalculateRecoinsAwards.new

  result = service.calculate_recoins(steps, transactions)
  result.none? { |r| r[:type] == 'MonthlyStreakTwelveThousandFive' }
end

def thirty_day_streak_should_not_be_given_yet_as_not_enough_steps
  steps = []
  times = generate_time_array(CalculateRecoinsAwards.new.thirty_days_ago)
  times.each do |time|
    steps << { step_count: 10_000, date: time }
  end

  transactions = [
    { parent_id: 'MonthlyStreakTwelveThousandFive', created_at: times[0] },
  ]

  service = CalculateRecoinsAwards.new

  result = service.calculate_recoins(steps, transactions)
  result.none? { |r| r[:type] == 'MonthlyStreakTwelveThousandFive' }
end

puts "thirty day streaks: #{test_result thirty_day_streak_works}"
puts "thirty day streaks should not be given as already awarded : #{test_result thirty_day_streak_should_not_be_given_yet_as_already_awarded}"
puts "thirty day streaks should not be given as not enough steps : #{test_result thirty_day_streak_should_not_be_given_yet_as_not_enough_steps}"
