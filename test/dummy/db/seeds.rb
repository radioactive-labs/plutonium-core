# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Create Users
puts "Creating users..."
users = 5.times.map do |i|
  User.find_or_create_by!(email: "user#{i + 1}@example.com") do |u|
    u.password_hash = BCrypt::Password.create("password123")
    u.status = 2 # verified
  end
end

# Create Admin
puts "Creating admin..."
Admin.find_or_create_by!(email: "admin@example.com") do |a|
  a.password_hash = BCrypt::Password.create("password123")
  a.status = 2 # verified
end

# Create Categories
puts "Creating categories..."
categories = [
  {name: "Electronics", description: "Gadgets, devices, and electronic accessories"},
  {name: "Clothing", description: "Apparel and fashion items"},
  {name: "Home & Garden", description: "Furniture, decor, and garden supplies"},
  {name: "Sports & Outdoors", description: "Athletic gear and outdoor equipment"},
  {name: "Books", description: "Physical and digital books"}
].map do |attrs|
  DemoFeatures::Category.find_or_create_by!(name: attrs[:name]) do |c|
    c.description = attrs[:description]
  end
end

# Create Tags
puts "Creating tags..."
tags = [
  {name: "New Arrival", color: "#22c55e"},
  {name: "Best Seller", color: "#eab308"},
  {name: "On Sale", color: "#ef4444"},
  {name: "Limited Edition", color: "#8b5cf6"},
  {name: "Eco-Friendly", color: "#14b8a6"},
  {name: "Premium", color: "#f59e0b"},
  {name: "Staff Pick", color: "#3b82f6"}
].map do |attrs|
  DemoFeatures::Tag.find_or_create_by!(name: attrs[:name]) do |t|
    t.color = attrs[:color]
  end
end

# Create Products
puts "Creating products..."
products_data = [
  {
    name: "Wireless Bluetooth Headphones",
    sku: "ELEC-WBH-001",
    category: categories[0],
    price: 79.99,
    compare_at_price: 99.99,
    status: :active,
    featured: true,
    active: true,
    description: "Premium wireless headphones with noise cancellation and 30-hour battery life.",
    tags: [tags[0], tags[1], tags[5]]
  },
  {
    name: "Smart Watch Pro",
    sku: "ELEC-SWP-002",
    category: categories[0],
    price: 299.99,
    compare_at_price: 349.99,
    status: :active,
    featured: true,
    active: true,
    description: "Advanced smartwatch with health monitoring, GPS, and 5-day battery.",
    tags: [tags[1], tags[5]]
  },
  {
    name: "USB-C Hub 7-in-1",
    sku: "ELEC-UCH-003",
    category: categories[0],
    price: 49.99,
    compare_at_price: 49.99,
    status: :active,
    featured: false,
    active: true,
    description: "Compact hub with HDMI, USB-A, SD card reader, and ethernet ports.",
    tags: [tags[6]]
  },
  {
    name: "Vintage Denim Jacket",
    sku: "CLTH-VDJ-001",
    category: categories[1],
    price: 89.99,
    compare_at_price: 120.00,
    status: :active,
    featured: true,
    active: true,
    description: "Classic denim jacket with a modern fit. Sustainable materials.",
    tags: [tags[2], tags[4]]
  },
  {
    name: "Cotton Crew Neck T-Shirt",
    sku: "CLTH-CNT-002",
    category: categories[1],
    price: 24.99,
    compare_at_price: 24.99,
    status: :active,
    featured: false,
    active: true,
    description: "Soft, breathable 100% organic cotton t-shirt.",
    tags: [tags[4], tags[1]]
  },
  {
    name: "Running Shoes Elite",
    sku: "CLTH-RSE-003",
    category: categories[1],
    price: 149.99,
    compare_at_price: 179.99,
    status: :active,
    featured: true,
    active: true,
    description: "Lightweight performance running shoes with responsive cushioning.",
    tags: [tags[0], tags[5]]
  },
  {
    name: "Minimalist Desk Lamp",
    sku: "HOME-MDL-001",
    category: categories[2],
    price: 59.99,
    compare_at_price: 75.00,
    status: :active,
    featured: false,
    active: true,
    description: "Modern LED desk lamp with adjustable brightness and color temperature.",
    tags: [tags[6], tags[4]]
  },
  {
    name: "Indoor Plant Set",
    sku: "HOME-IPS-002",
    category: categories[2],
    price: 39.99,
    compare_at_price: 39.99,
    status: :active,
    featured: true,
    active: true,
    description: "Set of 3 low-maintenance indoor plants with decorative pots.",
    tags: [tags[0], tags[4]]
  },
  {
    name: "Ergonomic Office Chair",
    sku: "HOME-EOC-003",
    category: categories[2],
    price: 399.99,
    compare_at_price: 499.99,
    status: :active,
    featured: true,
    active: true,
    description: "Premium ergonomic chair with lumbar support and adjustable armrests.",
    tags: [tags[1], tags[2], tags[5]]
  },
  {
    name: "Yoga Mat Premium",
    sku: "SPRT-YMP-001",
    category: categories[3],
    price: 45.99,
    compare_at_price: 55.00,
    status: :active,
    featured: false,
    active: true,
    description: "Extra thick, non-slip yoga mat made from natural rubber.",
    tags: [tags[4], tags[6]]
  },
  {
    name: "Camping Tent 4-Person",
    sku: "SPRT-CT4-002",
    category: categories[3],
    price: 199.99,
    compare_at_price: 249.99,
    status: :active,
    featured: true,
    active: true,
    description: "Waterproof 4-person tent with easy setup and ventilation.",
    tags: [tags[2], tags[1]]
  },
  {
    name: "Fitness Tracker Band",
    sku: "SPRT-FTB-003",
    category: categories[3],
    price: 49.99,
    compare_at_price: 49.99,
    status: :draft,
    featured: false,
    active: false,
    description: "Slim fitness tracker with heart rate monitoring and sleep tracking.",
    tags: [tags[0]]
  },
  {
    name: "The Art of Programming",
    sku: "BOOK-AOP-001",
    category: categories[4],
    price: 49.99,
    compare_at_price: 59.99,
    status: :active,
    featured: true,
    active: true,
    description: "Comprehensive guide to software craftsmanship and clean code.",
    tags: [tags[1], tags[6]]
  },
  {
    name: "Cooking Essentials",
    sku: "BOOK-COE-002",
    category: categories[4],
    price: 34.99,
    compare_at_price: 34.99,
    status: :active,
    featured: false,
    active: true,
    description: "Master the fundamentals of cooking with 200+ recipes.",
    tags: [tags[6]]
  },
  {
    name: "Mindfulness Journal",
    sku: "BOOK-MFJ-003",
    category: categories[4],
    price: 19.99,
    compare_at_price: 24.99,
    status: :archived,
    featured: false,
    active: false,
    description: "Guided journal for daily mindfulness practice and reflection.",
    tags: [tags[3], tags[2]]
  }
]

products = products_data.map do |data|
  product_tags = data.delete(:tags)

  product = DemoFeatures::Product.find_or_initialize_by(sku: data[:sku])
  product.assign_attributes(
    name: data[:name],
    category: data[:category],
    price: data[:price],
    compare_at_price: data[:compare_at_price],
    status: data[:status],
    featured: data[:featured],
    active: data[:active],
    description: data[:description],
    slug: data[:name].parameterize,
    stock_count: rand(0..100),
    weight: rand(0.1..10.0).round(2),
    taxable: [true, true, true, false].sample,
    notes: "Internal notes for #{data[:name]}",
    metadata: {source: "seed", version: 1},
    specifications: {material: "Various", origin: "Imported"},
    release_date: Date.today - rand(1..365).days,
    discontinue_date: Date.today + rand(180..730).days,
    published_at: data[:status] == :active ? Time.current - rand(1..90).days : Time.current,
    last_restocked_at: Time.current - rand(1..30).days,
    available_from_time: Time.parse("09:00"),
    available_until_time: Time.parse("21:00")
  )
  product.save!

  # Add tags
  product_tags.each_with_index do |tag, index|
    DemoFeatures::ProductTag.find_or_create_by!(product: product, tag: tag) do |pt|
      pt.position = index
    end
  end

  product
end

# Create Variants for some products
puts "Creating variants..."
products.first(8).each do |product|
  variant_options = case product.category.name
  when "Clothing"
    [{name: "Small", sku_suffix: "S"}, {name: "Medium", sku_suffix: "M"}, {name: "Large", sku_suffix: "L"}]
  when "Electronics"
    [{name: "Black", sku_suffix: "BLK"}, {name: "White", sku_suffix: "WHT"}, {name: "Silver", sku_suffix: "SLV"}]
  else
    [{name: "Standard", sku_suffix: "STD"}, {name: "Deluxe", sku_suffix: "DLX"}]
  end

  variant_options.each do |opt|
    DemoFeatures::Variant.find_or_create_by!(product: product, sku: "#{product.sku}-#{opt[:sku_suffix]}") do |v|
      v.name = opt[:name]
      v.price = product.price + rand(-10..20)
      v.stock_count = rand(0..50)
      v.active = product.active
      v.options = {variant_type: opt[:name].downcase}
    end
  end
end

# Create Reviews for active products
puts "Creating reviews..."
review_titles = [
  "Great product!",
  "Exactly what I needed",
  "Good value for money",
  "Exceeded expectations",
  "Solid purchase",
  "Would recommend",
  "Not bad",
  "Could be better",
  "Amazing quality",
  "Perfect!"
]

review_bodies = [
  "This product exceeded my expectations. The quality is excellent and it arrived quickly.",
  "Very happy with this purchase. Works exactly as described.",
  "Good product for the price. Would buy again.",
  "The quality is outstanding. I've recommended it to all my friends.",
  "Decent product but shipping took longer than expected.",
  "Love it! Perfect addition to my collection.",
  "Solid build quality and great design. Very satisfied.",
  "Works well but the instructions could be clearer.",
  "Fantastic product! Customer service was also very helpful.",
  "Met all my requirements. Simple and effective."
]

products.select { |p| p.status == "active" }.each do |product|
  rand(2..5).times do |i|
    user = users.sample
    next if DemoFeatures::Review.exists?(product: product, user: user)

    DemoFeatures::Review.create!(
      product: product,
      user: user,
      title: review_titles.sample,
      body: review_bodies.sample,
      rating: rand(3..5),
      verified: [true, true, false].sample,
      approved_at: [Time.current - rand(1..30).days, nil].sample || Time.current
    )
  end
end

# Create some blog posts
puts "Creating blog posts..."
5.times do |i|
  user = users.sample
  Blogging::Post.find_or_create_by!(title: "Blog Post #{i + 1}") do |p|
    p.body = "This is the content of blog post #{i + 1}. It contains interesting information about various topics."
    p.user = user
    p.published = [true, true, false].sample
  end
end

puts "Seeding complete!"
puts "Created:"
puts "  - #{User.count} users"
puts "  - #{Admin.count} admins"
puts "  - #{DemoFeatures::Category.count} categories"
puts "  - #{DemoFeatures::Tag.count} tags"
puts "  - #{DemoFeatures::Product.count} products"
puts "  - #{DemoFeatures::Variant.count} variants"
puts "  - #{DemoFeatures::Review.count} reviews"
puts "  - #{Blogging::Post.count} blog posts"
