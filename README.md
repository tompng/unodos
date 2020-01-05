# Unodos

```ruby
require 'unodos'
Unodos[1,2].take(5) # => [1,2,3,4,5]
Unodos[1,2,4].take(5) # => [1,2,4,8,16]
Unodos[1,1,2,3,5].take(8) # => [1,1,2,3,5,8,13,21]
Unodos[1,1,2,4,3,9,4,16,5].take(10) # => [1,1,2,4,3,9,4,16,5,25]

# to see the generated rule
Unodos[4,1,0,1,4,9].rule # => "a[n]=4-4*n+n**2"
Unodos[1,2,4,5,7,8].rule # => "a[n]=-a[n-1]+3*n"
```

## Installation

```ruby
gem 'unodos'
```

## Syntax Sugar

```ruby
require 'unodos/sugar' # will add Array#infinite
[1,2,3].infinite.take(5) #=> [1,2,3,4,5]
using Unodos::Sugar # will change [numbers, number..].some_method
[1,2...].take(5) #=> [1,2,3,4,5]
[1,1,2,3,5...].find_index(144) #=> 11
```
