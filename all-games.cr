used = Set(String).new

((1..10).to_a * 2 + [25, 50, 75, 100]).sort.each_combination(6) do |c|
  (100..999).each do |target|
    s = c.join(" ") + " " + target.to_s
    unless used.includes?(s)
      STDOUT << s << '\n'
      used << s
    end
  end
end
