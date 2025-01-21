require 'time'
require_relative '../tasks/calculate_recoins_awards'

ENV['ENV'] = 'test'

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

def test_result(result)
  result ? "\e[32mPASSED\e[0m" : "\e[31mFAIL\e[0m"
end
