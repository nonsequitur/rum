case Platform
when :mac     then require 'rum/mac/apps'
when :windows then require 'rum/windows/apps'
end
