This repo contains a solver for the "Numbers" game played on long-running game shows in the UK, France and Australia, a tiny program to generate all possible legal games, and an xz-compressed file containing solutions for all possible (~12 million) games.

Brief rules for the numbers game:

* 6 "source" numbers are chosen from a pool of 24. There are two each of all the digits from 1 to 10, plus one each of 25, 50, 75 and 100.
* A three-digit "target" number is randomly selected (between 100 and 999)
* The target number must be reached using the source numbers and the basic numerical operations of addition, subtraction, multiplication and division. These sub-rules apply:
  * Each source number may only be used in one operation, and each intermediate result can also only be used in one later operation
  * It is *not* necessary to use all of the source numbers
  * No intermediate result may be negative
  * All intermediate results must be integers
* Maximum points are scored for getting the exact target. Lower points are scored for getting up to 9 away. If the closest number attainable is 10 or more away, nothing is scored and there is considered to be no solution.
  
For example, with the source numbers 1 3 7 6 8 3 and target number 250 one possible solution is 8×3=24; 24+1=25; 7+3=10; 25×10=250. Note that here we had 2 3's in the source list so 3 could be used twice.

To build the solver:

    crystal build --release numbers.cr

See https://crystal-lang.org/reference/installation/ if you don't have the Crystal compiler.

The program accepts either 7 numbers on the command line (6 source and a target) or lines of 7 space-separated numbers on standard input. To solve the example above:

    numbers 1 3 7 6 8 3 250

To test using the included sample games:

    numbers < samples
    
The algorithm is basically exhaustive search with some simple trimming of the expression space for useless or disallowed operations. (A useless operation is, for example, 6÷1 since the result is one of the operands so doesn't accomplish anything.) On relatively modern hardware this still solves over 100 games per second. You can also add the `-a` flag to enable "anarchy mode": source numbers are no longer restricted to the pool, target numbers can be any positive integer, there can be any number of source numbers >=2, and a solution is printed no matter how far away it is from the target. Don't feed in crazy values; all calculations are done in 32-bit integers and there's no protection against overflow.
    
The file "all-numbers-solutions.xz" includes solutions to all possible games (not counting anarchy mode). This can be generated yourself by first building the all-game generator:

    crystal build --release all-games.cr
    
Then running it like this:

    all-games | numbers | xz -9 > all-numbers-solutions.xz

This will take less than a day on modern hardware. The code is not multi-threaded. Although `xz -9` is slow it compresses a lot faster than `numbers` can generate solutions, and has by far the best compression ratio with `numbers` output (more than 50:1).
