#!/usr/bin/env ruby

# Extract spectral peaks from a set of spectra.

require 'pry'
require 'nmatrix'

class Spectra
  def initialize filename
    d = []
    f = File.new(filename, 'r')
    while line = f.gets
      fields = line.chomp.split
      next if fields.any? { |field| field =~ /[a-df-zA-DF-Z]+/ }
      fields = fields.map { |field| field.to_f }
      next if fields.size != 3
      d << fields
    end
    d = d.flatten
    @data = NMatrix.new([d.size / 3, 3], d, dtype: :float64)
    @filename = filename
  end

  attr_reader :data, :filename

  # Return a list of wavelengths where minima are found.
  def minima
    found = []

    @data[:*,1].each.with_index do |ref,i|  # ref = reflectance
      if i == 0 # first
        if ref < @data[i+1,1]
          found << @data[i,0]
        end
      elsif i == @data.shape[0]-1 # last
        if ref < @data[i-1,1]
          found << @data[i,0]
        end
      else
        if ref < @data[i+1,1] && ref < @data[i-1,1]
          found << @data[i,0]
        end
      end
    end

    found
  end

  def to_a id
    ary = []
    @data.each_row do |row|
      next if row[0] < 0
      ary << { :x => row[0], :y => row[1]*1000, :id => id }
    end
    ary
  end
end

def get_all_minima
  all_minima = []
  ARGV.each do |filename|
    s = Spectra.new(filename)
    all_minima << s.minima
  end
  puts all_minima.flatten.sort.join("\n")
end