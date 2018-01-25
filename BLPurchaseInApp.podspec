
Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  s.name         = "BLPurchaseInApp"
  s.version      = "1.0.0"
  s.summary      = "A short description of BLPurchaseInApp."

 s.description  = "这是内购非常好的用法，不知道你会不会用，此处略去1000000000字。"

  s.homepage     = "https://github.com/Balopy"


  s.license      = { :type => "MIT", :file => "FILE_LICENSE" }


  s.author             = { "Balopy" => "lueng2yuan@163.com" }

  # s.platform     = :ios
  # s.platform     = :ios, "8.0"



  s.source       = { :git => "https://github.com/Balopy/BLPurchaseInApp.git", :tag => "#{s.version}" }


  s.source_files  = "PurchaseInApp/**/*.{h,m}"


  # s.frameworks = "StoreKit", "Foundation", "UIKit"


end
