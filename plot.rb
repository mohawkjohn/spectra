require 'plotrb'
require 'yaml'
require 'pry'

missions = YAML.load(File.read('missions.yaml'))[:missions]

spectra = Hash.new { |h,k| h[k] = [] }

missions.each do |mission|
  #puts "mission #{mission.inspect}"
  mission[:sensors].each do |sensor|
    #puts "\tsensor #{sensor.inspect}"
    if sensor.has_key?(:spectra) && !sensor[:spectra].nil?
      sensor[:spectra].each do |spectrum|
        spectra[sensor[:abbrev] || sensor[:name]] << spectrum.merge({:mission => (mission[:abbrev] || mission[:name])})
      end
    else
      STDERR.puts "sensor #{sensor[:abbrev] || sensor[:name]} on #{mission[:abbrev] || mission[:name]} is missing spectra"
    end
  end
end

spectra.each_pair do |key,ary|
  ary.each.with_index do |item,i|
    extra = {
        :id => key,
      }
    if item.has_key?(:peak)
      extra[:mean] = item[:peak]
    elsif item.has_key?(:low)
      if item.has_key?(:high)
        extra[:mean] = (item[:low] + item[:high]) / 2.0
      else
        extra[:mean] = (2*item[:low] + item[:resolution]) / 2.0 # no high given
      end
    elsif item.has_key?(:high)
      extra[:mean] = (2*item[:high] - item[:resolution]) / 2.0 # no low given
    end

    spectra[key][i] = item.merge(extra)
  end
end

spectra = spectra.values.flatten

data = pdata.name('spectra').values(spectra)

ys = ordinal_scale.name('sensors').from('spectra.mission').to_height
xs = linear_scale.name('x').from('spectra.mean').nicely.to_width

rm = rect_mark.from(data) do
  enter do
    x_start  { scale(xs).from(:low) }
    x_end    { scale(xs).from(:high)}
    y_start  { scale(ys).from(:mission)  }
    height   { scale(ys).offset(-1).use_band }
    fill '#ccc'
  end
  update do
    fill 'steelblue'
  end
  hover do
    fill 'red'
  end
end

# tm = text_mark.from(data) do
#   enter do
#     x       { scale(xs).from('spectra.mean')}
#     text    { field(:id) }
#     align :center
#     baseline :bottom
#     fill '#000'
#   end
# end

#tm = text_mark.from(data) do
#  enter do
#    x { scale(xs).from(:low) }
#    y { scale(ys).field(:id).offset(-2) }
#    text { field(:id) }
#    align :center
#    baseline :bottom
#    fill '#000'
#  end
#end


vis = visualization.width(600).height(700) do
  padding top: 10, left: 140, bottom: 30, right: 25
  data data
  scales xs, ys
  marks rm #, tm
  axes x_axis.scale(xs), y_axis.scale(ys)
end

puts vis.generate_spec(:pretty)

