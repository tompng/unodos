class Array
  def infinite(&block)
    inf = Unodos::Infinite.new(self)
    block ? inf.each(&block) : inf
  end
end

module Unodos::Sugar
  def self.target_array?(array)
    *items, last = array
    last.is_a?(Range) && last.end.nil? && items.all?(Numeric)
  end
  refine Array do
    %i[each map take find_index first take_while].each do |method|
      define_method method do |*args, **kwargs, &block|
        if Unodos::Sugar.target_array? self
          *items, last = self
          Unodos::Infinite.new(items + [last.begin]).send(method, *args, **kwargs, &block)
        else
          super
        end
      end
    end
  end
end