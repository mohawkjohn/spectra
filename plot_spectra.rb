#!/usr/local/bin/ruby

require 'plotrb'

d = []

while line = gets
  fields = line.chomp.split.map { |x| x.to_f }
  d << { x: fields[0], y: fields[1]*1000, err: fields[2] }
end

d.delete_if { |x| x[:y] < 0 }

data = pdata.name('spectra').values(d)

xs = linear_scale.name('x').from('spectra.x').to_width
ys = linear_scale.name('y').from('spectra.y').to_height.nicely.exclude_zero

xa = x_axis.scale(xs).ticks(10)
ya = y_axis.scale(ys).ticks(5)

line = line_mark.from(data) do
  enter do
    interpolate :monotone
    x_start { from('x').scale(xs) }
    y_start { from('y').scale(ys) }
    y_end   { value(0).scale(ys)  }
    stroke 'steelblue'
  end
end

vis = visualization.name('line').width(500).height(300) do
  padding top: 10, left: 60, bottom: 30, right: 10
  data data
  scales xs, ys
  axes xa, ya
  marks line
end

puts vis.generate_spec(:pretty)
