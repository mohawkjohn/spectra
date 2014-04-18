require 'plotrb'
require 'yaml'
require 'pry'

WIDTH=700

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

      # Make sure it has a low and a high
      if !item.has_key?(:low) && !item.has_key?(:high)
        unless item.has_key?(:resolution)
          raise("resolution missing for item #{item.inspect}")
        end
        extra[:low]  = item[:peak] - item[:resolution]/2.0
        extra[:high] = item[:peak] + item[:resolution]/2.0
      elsif item.has_key?(:low) && !item.has_key?(:high)
        extra[:high] = item[:low] + item[:resolution]
      elsif item.has_key?(:high) && !item.has_key?(:low)
        extra[:low] = item[:high] - item[:resolution]
      end
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

    # Make sure we have a resolution for the heatmap
    spectra[key][i][:resolution] ||= spectra[key][i][:high] - spectra[key][i][:low]
  end
end

spectra = spectra.values.flatten

data = pdata.name('spectra').values(spectra)

ys = ordinal_scale.name('sensors').from('spectra.mission').to_height
xs = pow_scale.name('x').from('spectra.mean').exponent(0.1).domain([100,1000000]).range([-400.0, WIDTH.to_f])
cs = log_scale.name('c').from('spectra.resolution').domain([1.0,1000.0]).range(['red', 'yellow'])

rm = rect_mark.from(data) do
  enter do
    x_start  { scale(xs).from(:low) }
    x_end    { scale(xs).from(:high)}
    y_start  { scale(ys).from(:mission)  }
    height   { scale(ys).offset(-1).use_band }
    fill     { scale(cs).from(:resolution) }
    #fill '#ccc'
    #stroke 'red'
  end
  #update do
  #  fill     { scale(cs).from(:resolution) }
  #end
  #hover do
  #  fill 'purple'
  #end
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


vis = visualization.width(WIDTH).height(600) do
  padding top: 10, left: 140, bottom: 30, right: 25
  data data
  scales xs, ys, cs
  marks rm #, tm
  axes x_axis.scale(xs).values([100,300,600,1000,2500,5000,10000,25000,50000,100000,250000,500000,1000000]), y_axis.scale(ys)
end

puts vis.generate_spec(:pretty)

