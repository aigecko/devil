# (C) John Mair 2009, under the MIT licence

require 'texplay'
require 'devil'

# monkey patches for TexPlay module (and by proxy the Gosu::Image class)
module TexPlay

    # save a Gosu::Image to +file+
    # This method is only available if require 'devil/gosu' is used
    def save(file)
        capture {
            img = to_devil
            img.save(file)
            img.free
        }
        self
    end

    # convert a Gosu::Image to a Devil::Image.
    # This method is only available if require 'devil/gosu' is used
    def to_devil
        devil_img = nil
        capture {
            devil_img = Devil.from_blob(self.to_blob, self.width, self.height).flip
            devil_img
        }
        devil_img
    end
end

# monkey patches for Gosu::Window class
class Gosu::Window

    # return a screenshot of the framebuffer as a Devil::Image.
    # This method is only available if require 'devil/gosu' is used
    def screenshot
        require 'opengl'

        img = nil
        self.gl do
            data = glReadPixels(0, 0, self.width, self.height, GL_RGBA, GL_UNSIGNED_BYTE)
            img = Devil.from_blob(data, self.width, self.height)
        end
        
        img
    end
end

class Gosu::Image
    class << self
        alias_method :original_new_redux, :new
        
        # monkey patching to support multiple image formats.
        # This method is only available if require 'devil/gosu' is used
        def new(window, file, *args, &block)
            if file.respond_to?(:to_blob) || file =~ /\.(bmp|png)$/
                original_new_redux(window, file, *args, &block)
            else
                img = Devil.load(file).flip
                begin
                    gosu_img = original_new_redux(window, img, *args, &block)
                ensure
                    img.free
                end

                gosu_img
            end
        end
    end
end

class Devil::Image

    # convert a Devil::Image to a Gosu::Image.
    # Must provide a +window+ parameter, as per Gosu::Image#new()
    # This method is only available if require 'devil/gosu' is used
    def to_gosu(window)
        Gosu::Image.new(window, self)
    end
    
    # display the Devil images on screen utilizing the Gosu library for visualization
    # if +x+ and +y+ are specified then show the image centered at this location, otherwise
    # draw the image at the center of the screen 
    # This method is only available if require 'devil/gosu' is used
    def show(x = Devil.get_options[:window_size][0] / 2,
             y = Devil.get_options[:window_size][1] / 2)
        
        if !Devil.const_defined?(:Window)
            c = Class.new(Gosu::Window) do
                attr_accessor :show_list
                
                def initialize
                    super(Devil.get_options[:window_size][0], Devil.get_options[:window_size][1], false)
                    @show_list = []
                end

                def draw    # :nodoc:
                    @show_list.each { |v| v[:image].draw_rot(v[:x], v[:y], 1, 0) }

                    exit if button_down?(Gosu::KbEscape)
                end
            end

            Devil.const_set :Window, c
        end
        
        if !defined? @@window
            @@window ||= Devil::Window.new

            at_exit { @@window.show }
        end

        # note we dup the image so the displayed image is a snapshot taken at the time #show is invoked

        img = self.dup.flip
        @@window.show_list.push :image => Gosu::Image.new(@@window, img), :x => x, :y => y
        img.free
        
        self
    end
end
