require 'time'
require_relative '../tasks/calculate_recoins_awards'

def generate_time_array(start_time)
  # Get the end date as today at the same time
  end_time = Time.now

  # Check if the start date is in the future
  if start_time > end_time
    raise "Start date cannot be in the future."
  end

  # Generate an array of Time objects from start_time to end_time (1 day intervals)
  time_array = []
  current_time = start_time

  while current_time <= end_time
    time_array << current_time
    current_time += 86_400 # Add 1 day in seconds
  end

  time_array
end

def fouteen_day_streak_works
  steps = []
  times = generate_time_array(CalulateRecoinsAwards.new.fourteen_days_ago)
  times.each do |time|
    steps << { step_count: 15_000, date: time }
  end

  transactions = []

  service = CalulateRecoinsAwards.new

  result = service.calculate_recoins(steps, transactions)
  result.any? { |r| r[:type] == 'StreakFourteenThousand' }
end

def fouteen_day_streak_should_not_be_given_yet_as_already_awarded
  steps = []
  times = generate_time_array(CalulateRecoinsAwards.new.fourteen_days_ago)
  times.each do |time|
    steps << { step_count: 15_000, date: time }
  end

  transactions = [
    { parent_id: 'StreakFourteenThousand', created_at: times[1] },
  ]

  service = CalulateRecoinsAwards.new

  result = service.calculate_recoins(steps, transactions)
  result.none? { |r| r[:type] == 'StreakFourteenThousand' }
end

def fouteen_day_streak_should_not_be_given_yet_as_not_enough_steps
  steps = []
  times = generate_time_array(CalulateRecoinsAwards.new.fourteen_days_ago)
  times.each do |time|
    steps << { step_count: 10_000, date: time }
  end

  transactions = [
    { parent_id: 'StreakFourteenThousand', created_at: times[0] },
  ]

  service = CalulateRecoinsAwards.new

  result = service.calculate_recoins(steps, transactions)
  result.none? { |r| r[:type] == 'StreakFourteenThousand' }
end

def test_result(result)
  result ? "\e[32mPASSED\e[0m" : "\e[31mFAIL\e[0m"
end 

puts "Fourteen day streaks: #{test_result fouteen_day_streak_works}"
puts "Fourteen day streaks should not be given as already awarded : #{test_result fouteen_day_streak_should_not_be_given_yet_as_already_awarded}"
puts "Fourteen day streaks should not be given as not enough steps : #{test_result fouteen_day_streak_should_not_be_given_yet_as_not_enough_steps}"