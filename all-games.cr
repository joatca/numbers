
((1..10).to_a * 2 + [25, 50, 75, 100]).sort.each_combination(6) do |c|
  (100..999).each do |target|
    c.join(" ", STDOUT)
    STDOUT << " " << target << '\n'
  end
end
