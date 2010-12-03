# encoding: UTF-8

require 'theseus/mask'

module Theseus
  class Maze
    NORTH = 0x01
    SOUTH = 0x02
    EAST  = 0x04
    WEST  = 0x08

    DIRECTIONS = [NORTH, SOUTH, EAST, WEST]

    attr_reader :width, :height

    def self.generate(width, height, options={})
      maze = new(width, height, options)
      maze.generate!
      return maze
    end

    def initialize(width, height, options={})
      @width = width
      @height = height
      @randomness = options[:randomness] || 100
      @mask = options[:mask] || TransparentMask.new
      @cells = Array.new(height) { Array.new(width, 0) }
      loop do
        @x = rand(@width)
        @y = rand(@height)
        break if @mask[@x, @y]
      end
      @tries = new_tries
      @stack = []
      @generated = false
    end

    def new_tries
      DIRECTIONS.sort_by { rand }
    end

    def [](x,y)
      @cells[y][x]
    end

    def []=(x,y,value)
      @cells[y][x] = value
    end

    def generated?
      @generated
    end

    def dx(direction)
      case direction
      when EAST then 1
      when WEST then -1
      else 0
      end
    end

    def dy(direction)
      case direction
      when SOUTH then 1
      when NORTH then -1
      else 0
      end
    end

    def opposite(direction)
      case direction
      when NORTH then SOUTH
      when SOUTH then NORTH
      when EAST  then WEST
      when WEST  then EAST
      end
    end

    def d2s(direction)
      case direction
      when NORTH then "north"
      when SOUTH then "south"
      when EAST  then "west"
      when WEST  then "east"
      end
    end

    def next_direction
      loop do
        direction = @tries.pop
        nx, ny = @x + dx(direction), @y + dy(direction)

        if nx >= 0 && ny >= 0 && nx < @width && ny < @height && @cells[ny][nx] == 0 && @mask[nx, ny]
          return direction
        end

        while @tries.empty?
          if @stack.empty?
            @generated = true
            return nil
          else
            @x, @y, @tries = @stack.pop
          end
        end
      end
    end

    def step
      return nil if @generated

      direction = next_direction or return nil
      nx, ny = @x + dx(direction), @y + dy(direction)

      @cells[@y][@x] |= direction
      @cells[ny][nx] |= opposite(direction)

      @stack.push([@x, @y, @tries])
      @tries = new_tries
      @tries.push direction unless rand(100) < @randomness
      @x, @y = nx, ny

      return [nx, ny]
    end

    def generate!
      while (cell = step)
        yield cell if block_given?
      end
    end

    def sparsify!
      dead_ends = []

      @cells.each_with_index do |row, y|
        row.each_with_index do |cell, x|
          if cell == NORTH || cell == SOUTH || cell == EAST || cell == WEST
            dead_ends << [x, y]
          end
        end
      end

      dead_ends.each do |(x, y)|
        cell = @cells[y][x]
        nx, ny = x + dx(cell), y + dy(cell)
        @cells[y][x] = 0
        @cells[ny][nx] &= ~opposite(cell)
      end
    end

    def inspect
      "#<Maze:0x%X %dx%d %s>" % [
        object_id, @width, @height,
        generated? ? "generated" : "not generated"]
    end

    def to_s(mode=nil)
      case mode
      when nil then to_simple_ascii
      when :utf8_lines then to_utf8_lines
      when :utf8_halls then to_utf8_halls
      else raise ArgumentError, "unknown mode #{mode.inspect}"
      end
    end

    def to(format, options={})
      case format
      when :png then
        require 'theseus/formatters/png'
        Formatters::PNG.new(self, options).to_blob
      else
        raise ArgumentError, "unknown format: #{format.inspect}"
      end
    end

    SIMPLE_SPRITES = [
      ["   ", "   "], # " "
      ["| |", "+-+"], # "╵"
      ["+-+", "| |"], # "╷"
      ["| |", "| |"], # "│",
      ["+--", "+--"], # "╶" 
      ["| .", "+--"], # "└" 
      ["+--", "| ."], # "┌"
      ["| .", "| ."], # "├" 
      ["--+", "--+"], # "╴"
      [". |", "--+"], # "┘"
      ["--+", ". |"], # "┐"
      [". |", ". |"], # "┤"
      ["---", "---"], # "─"
      [". .", "---"], # "┴"
      ["---", ". ."], # "┬"
      [". .", ". ."]  # "┼"
    ]

    UTF8_SPRITES = [
      ["   ", "   "], # " "
      ["│ │", "└─┘"], # "╵"
      ["┌─┐", "│ │"], # "╷"
      ["│ │", "│ │"], # "│",
      ["┌──", "└──"], # "╶" 
      ["│ └", "└──"], # "└" 
      ["┌──", "│ ┌"], # "┌"
      ["│ └", "│ ┌"], # "├" 
      ["──┐", "──┘"], # "╴"
      ["┘ │", "──┘"], # "┘"
      ["──┐", "┐ │"], # "┐"
      ["┘ │", "┐ │"], # "┤"
      ["───", "───"], # "─"
      ["┘ └", "───"], # "┴"
      ["───", "┐ ┌"], # "┬"
      ["┘ └", "┐ ┌"]  # "┼"
    ]

    UTF8_LINES = [" ", "╵", "╷", "│", "╶", "└", "┌", "├", "╴", "┘", "┐", "┤", "─", "┴", "┬", "┼"]

    def render_with_sprites(sprites)
      str = ""
      @cells.each do |row|
        r1, r2 = "", ""
        row.each do |cell|
          sprite = sprites[cell]
          r1 << sprite[0]
          r2 << sprite[1]
        end
        str << r1 << "\n"
        str << r2 << "\n"
      end
      str
    end

    def to_simple_ascii
      render_with_sprites(SIMPLE_SPRITES)
    end

    def to_utf8_halls
      render_with_sprites(UTF8_SPRITES)
    end

    def to_utf8_lines
      str = ""
      @cells.each do |row|
        row.each do |cell|
          str << UTF8_LINES[cell]
        end
        str << "\n"
      end
      str
    end
  end
end