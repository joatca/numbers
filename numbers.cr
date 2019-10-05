require "option_parser"

# using a struct here is twice as fast as a class because it structs are value types and stack-allocated so
# there's much less load on the garbage collector
struct Step
  
  def initialize(@op : Char, @v1 : Int32, @v2 : Int32, @result : Int32)
  end
  
  # this enables the @steps.join output trick in Game#show_steps
  def to_s(io : IO)
    io << @v1 << @op << @v2 << '=' << @result
  end
end

class Add
  def calc(v1, v2 : Int32)
    if v1 >= v2 # we can apply this because addition is commutative - we can ignore half of the combinations
      result = v1 + v2
      yield result if result != v1 && result != v2
    end
  end

  def sym; '+'; end
end

class Sub
  def calc(v1, v2 : Int32)
    if v1 > v2 # intermediate results may not be negative
      result = v1 - v2
      yield result if result != v1 && result != v2
    end
  end

  def sym; '-'; end
end

class Mul
  def calc(v1, v2 : Int32)
    if v1 >= v2 # we can apply this because multiplication is commutative - we can ignore half of the combinations
      result = v1 * v2
      yield result if result != v1 && result != v2
    end
  end

  def sym; '×'; end
end

class Div
  def calc(v1, v2 : Int32)
    if v1 % v2 == 0 # integer division only - since we never have zeroes this also checks that v1 > v2
      result = v1 // v2
      yield result if result != v1 && result != v2
    end
  end

  def sym; '÷'; end
end

alias Op = Add | Sub | Mul | Div

struct Game
  ALLOWED_OPERATIONS = [ Add.new, Sub.new, Mul.new, Div.new ]

  @best_away : Int32
  
  def initialize(@maxaway : Int32, @sources : Array(Int32), @target : Int32)
    # the maximum entries needed for each of these arrays can't exceed MAXNUMS so we preallocate enough space,
    # and thus avoid dynamically resizing; we manage these arrays internally to the class instead of passing
    # around new objects for performance reasons and to avoid putting pressure on the garbage collector
    maxnums = @sources.size
    @stack = Array(Int32).new(maxnums) # expression stack
    @steps = Array(Step).new(maxnums) # record of the steps so far
    @avail = Array(Bool).new(maxnums, true) # whether each number has been used
    @best = Array(Step).new(maxnums) # best one within maxaway found so far
    @best_away = @maxaway + 1 # something greater than the max value that can trigger recording a best
  end

  # abstract away the push-a-step, do-something, pop-step action
  def with_step(step : Step)
    @steps.push(step)
    yield
    @steps.pop
  end

  # abstract away the push-a-result, do-something, pop-the-result action
  def with_value_on_stack(value : Int32)
    @stack.push(value)
    yield
    @stack.pop
  end

  # and abstract away popping two values, doing something with them, then pushing them back again
  def with_top_values
    v2, v1 = @stack.pop, @stack.pop # note the reverse order
    yield v1, v2
    @stack.push v1
    @stack.push v2
  end
  
  def try_op(depth : Int32, op : Op) # do something with the top two numbers
    found = false
    with_top_values do |v1, v2|
      op.calc(v1, v2) do |result|
        # note that we push the step onto the step stack *before* checking whether we got the target, that way
        # we can just call show_steps immediately
        with_step(Step.new(op.sym, v1, v2, result)) do
          if result == @target
            show_steps(@steps, 0)
            found = true
          else
            # if not the target, is this the closest we've gotten to the target yet?
            away = (result - @target).abs
            if (away < @best_away)
              # we're using an idiom here that clears the @best array then copies @steps to it, rather than
              # simply cloning @steps to @best_away as a new object (which feels more natural in Ruby/Crystal);
              # the extra performance isn't really needed here but let's be efficient anyway
              @best.clear.concat(@steps)
              @best_away = away
            end
            # and finally, recurse with the result on the compute stack
            with_value_on_stack(result) do
              found = solve_depth(depth)
            end
          end
        end
      end
    end
    found
  end

  def solve_depth(depth : Int32)
    # when depth is > 0 we can keep trying to push numbers
    if depth > 0
      # rather than managing a set and adding/removing available numbers (with the resulting hashing penalty),
      # since we only have 6 numbers it's faster to loop through them every time and just use an array of
      # booleans to note which are available
      @sources.each_with_index do |num, i|
        if @avail[i]
          @avail[i] = false
          with_value_on_stack(num) do
            return true if solve_depth(depth-1)
          end
          @avail[i] = true
        end
      end
    end
    # with at least 2 numbers in the stack we can try operators; this expression calls try_op on each of
    # ALLOWED_OPERATIONS in sequence and returns true as soon as any of the calls return true, false if none do
    return ALLOWED_OPERATIONS.any? { |op| try_op(depth, op) } if @stack.size >= 2
    # and if we get this far nothing worked
    return false
  end

  def show_steps(steps, away = 0)
    steps.join("; ", STDOUT) # works because of Step#to_s
    puts (away > 0 ? " (#{away} away)" : "")
  end
  
  def solve(depths : Enumerable(Int32), show_problem : Bool)
    print "#{@sources.join(",")};#{@target} " if show_problem
    # if any of the source numbers match the target then just print that and exit
    if @sources.includes?(@target)
      puts "#{@target}=#{@target}"
    else
      # this converts e.g. [25, 50, 1, 1, 6, 7] to [[1, 1], [6, 7, 25, 50 ]], i.e. sort everything then separate
      # the ones from the non-ones, with the first non-one being the smallest
      ones, rest = @sources.sort.partition { |n| n == 1 }
      rest[0] += ones.size # if we have any 1s, add them to the next highest number (the lowest of the remaining
                           # numbers) before multiplying so we get the max possible result - if the resulting
                           # product is less than the target then there can be no exact solution
      if rest.product < @target
        puts "none"
      else
        depths.each do |max_depth|
          return if solve_depth(max_depth)
        end
        if @best_away <= @maxaway
          show_steps(@best, @best_away)
        else
          puts "none"
        end
      end
    end
  end

end

quick = false
anarchy = false

OptionParser.parse do |parser|
  parser.banner = "Usage: #{PROGRAM_NAME}"
  parser.on("-q", "--quick", "find any solution instead of shortest solution (faster)") {
    quick = true
  }
  parser.on("-a", "--anarchy", "any target > 0, any source numbers > 0, any number of source numbers") {
    anarchy = true
  }
  parser.on("-h", "--help", "Show this help") {
    puts parser
    exit(0)
  }
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
end

def do_arguments(quick : Bool, args : Array(String), anarchy, show_problem = true)
  if anarchy
    raise "need at least 2 source numbers and a target" unless args.size >= 3
  else
    raise "need exactly 6 source numbers and a target" unless args.size == 7
  end
  depths = if quick
             [ args.size - 1 ]
           else
             (2..(args.size - 1))
           end
  numbers = args.map { |s| s.to_i }
  sources, target = numbers[0...-1], numbers[-1]
  if anarchy
    raise "numbers must be positive" unless sources.all? { |n| n > 0 }
    raise "target must be positive" unless target > 0
  else
    raise "numbers may only be either 1..10 or 25/50/75/100" unless sources.all? { |n|
      (n >= 1 && n <= 10) || { 25, 50, 75, 100 }.includes?(n)
    }
    raise "target must be 100..999" unless target >= 100 && target <= 999
  end
  maxaway = anarchy ? target : 9
  Game.new(maxaway, sources, target).solve(depths, show_problem)
end

begin
  if ARGV.size > 0
    do_arguments(quick, ARGV, anarchy, false)
  else
    STDIN.each_line do |line|
      # this will raise if something isn't a number but we catch it further down
      do_arguments(quick, line.chomp.split, anarchy)
    end
  end
rescue e : Exception
  puts "#{e.message}"
end
