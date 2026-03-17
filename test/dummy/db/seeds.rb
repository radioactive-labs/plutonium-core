# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Admin
puts "Creating admin..."
admin = Admin.find_or_create_by!(email: "admin@plutonium.dev") do |a|
  a.password_hash = BCrypt::Password.create("password123")
  a.status = 2 # verified
end

# Users
puts "Creating users..."
alice = User.find_or_create_by!(email: "alice@acme.com") do |u|
  u.password_hash = BCrypt::Password.create("password123")
  u.status = 2
end

bob = User.find_or_create_by!(email: "bob@acme.com") do |u|
  u.password_hash = BCrypt::Password.create("password123")
  u.status = 2
end

carol = User.find_or_create_by!(email: "carol@globex.com") do |u|
  u.password_hash = BCrypt::Password.create("password123")
  u.status = 2
end

dave = User.find_or_create_by!(email: "dave@globex.com") do |u|
  u.password_hash = BCrypt::Password.create("password123")
  u.status = 2
end

# Organizations
puts "Creating organizations..."
acme = Organization.find_or_create_by!(name: "Acme Corp")
globex = Organization.find_or_create_by!(name: "Globex Inc")

# Memberships
puts "Creating memberships..."
OrganizationUser.find_or_create_by!(organization: acme, user: alice) { |m| m.role = :owner }
OrganizationUser.find_or_create_by!(organization: acme, user: bob) { |m| m.role = :member }
OrganizationUser.find_or_create_by!(organization: globex, user: carol) { |m| m.role = :owner }
OrganizationUser.find_or_create_by!(organization: globex, user: dave) { |m| m.role = :admin }

# Blogging: Tags
puts "Creating tags..."
tags = {
  tech: Blogging::Tag.find_or_create_by!(name: "Technology") { |t| t.color = "#3B82F6" },
  design: Blogging::Tag.find_or_create_by!(name: "Design") { |t| t.color = "#8B5CF6" },
  business: Blogging::Tag.find_or_create_by!(name: "Business") { |t| t.color = "#10B981" },
  tutorial: Blogging::Tag.find_or_create_by!(name: "How-To") { |t| t.color = "#F59E0B" },
  news: Blogging::Tag.find_or_create_by!(name: "News") { |t| t.color = "#EF4444" }
}

# Blogging: Posts (with STI)
puts "Creating blog posts..."
posts = []

posts << Blogging::Article.find_or_create_by!(title: "Getting Started with Plutonium") do |p|
  p.body = "Plutonium is a powerful Rails RAD framework that helps you build applications faster. In this article, we explore its core features and how to get started."
  p.user = alice
  p.organization = acme
  p.status = :published
end

posts << Blogging::Article.find_or_create_by!(title: "Building Multi-Tenant SaaS Apps") do |p|
  p.body = "Learn how to leverage Plutonium's portal system and entity scoping to build robust multi-tenant applications with proper data isolation."
  p.user = bob
  p.organization = acme
  p.status = :published
end

posts << Blogging::Tutorial.find_or_create_by!(title: "Custom Actions & Interactions") do |p|
  p.body = "Step-by-step guide to creating custom actions using Plutonium's interaction system. We'll build publish, archive, and bulk operations."
  p.user = carol
  p.organization = globex
  p.status = :published
end

posts << Blogging::Tutorial.find_or_create_by!(title: "Advanced Query Filters") do |p|
  p.body = "Deep dive into Plutonium's query system: text search, association filters, date ranges, scopes, and custom sorting."
  p.user = carol
  p.organization = globex
  p.status = :draft
end

posts << Blogging::Article.find_or_create_by!(title: "Plutonium Roadmap 2026") do |p|
  p.body = "A look at what's coming next for Plutonium: improved theming, API mode, real-time features, and more."
  p.user = alice
  p.organization = acme
  p.status = :archived
end

posts << Blogging::Post.find_or_create_by!(title: "Draft Post - WIP") do |p|
  p.body = "This is a work in progress post that hasn't been categorized yet."
  p.user = dave
  p.organization = globex
  p.status = :draft
end

# Post Details
posts.first(3).each do |post_record|
  Blogging::PostDetail.find_or_create_by!(post: post_record) do |d|
    d.seo_title = "#{post_record.title} | Plutonium Blog"
    d.seo_description = post_record.body.truncate(160)
    d.canonical_url = "https://plutonium.dev/blog/#{post_record.title.parameterize}"
  end
end

# Post Tags
posts[0].tags = [tags[:tech], tags[:tutorial]] unless posts[0].post_tags.any?
posts[1].tags = [tags[:tech], tags[:business]] unless posts[1].post_tags.any?
posts[2].tags = [tags[:tutorial], tags[:tech]] unless posts[2].post_tags.any?
posts[3].tags = [tags[:tutorial]] unless posts[3].post_tags.any?
posts[4].tags = [tags[:news], tags[:business]] unless posts[4].post_tags.any?

# Comments (polymorphic)
puts "Creating comments..."
posts.select(&:published?).each do |post_record|
  [alice, bob, carol, dave].sample(2).each do |user|
    Comment.find_or_create_by!(commentable: post_record, user: user) do |c|
      c.body = ["Great article!", "Very helpful, thanks for sharing.", "Looking forward to more content like this.", "This is exactly what I needed."].sample
    end
  end
end

# Catalog: Categories (self-referential)
puts "Creating categories..."
electronics = Catalog::Category.find_or_create_by!(name: "Electronics") { |c| c.description = "Gadgets, devices, and accessories" }
phones = Catalog::Category.find_or_create_by!(name: "Phones") { |c| c.description = "Smartphones and mobile devices"; c.parent = electronics }
laptops = Catalog::Category.find_or_create_by!(name: "Laptops") { |c| c.description = "Portable computers"; c.parent = electronics }
accessories = Catalog::Category.find_or_create_by!(name: "Accessories") { |c| c.description = "Cases, chargers, and more"; c.parent = electronics }
clothing = Catalog::Category.find_or_create_by!(name: "Clothing") { |c| c.description = "Apparel and fashion" }
books = Catalog::Category.find_or_create_by!(name: "Books") { |c| c.description = "Physical and digital books" }

# Catalog: Products (has_cents, enum, JSON)
puts "Creating products..."
products = []

products << Catalog::Product.find_or_create_by!(name: "iPhone 16 Pro") do |p|
  p.category = phones
  p.user = alice
  p.organization = acme
  p.price_cents = 99900
  p.status = :active
  p.description = "The latest iPhone with advanced camera system and A18 Pro chip."
  p.metadata = {brand: "Apple", year: 2025, colors: ["black", "white", "titanium"]}
end

products << Catalog::Product.find_or_create_by!(name: "MacBook Air M4") do |p|
  p.category = laptops
  p.user = alice
  p.organization = acme
  p.price_cents = 129900
  p.status = :active
  p.description = "Ultra-thin laptop with M4 chip, 18-hour battery life."
  p.metadata = {brand: "Apple", year: 2025, storage: ["256GB", "512GB", "1TB"]}
end

products << Catalog::Product.find_or_create_by!(name: "USB-C Hub 7-in-1") do |p|
  p.category = accessories
  p.user = bob
  p.organization = acme
  p.price_cents = 4999
  p.status = :active
  p.description = "Compact hub with HDMI, USB-A, SD card reader, and ethernet."
  p.metadata = {brand: "Anker", ports: 7}
end

products << Catalog::Product.find_or_create_by!(name: "Galaxy S25 Ultra") do |p|
  p.category = phones
  p.user = carol
  p.organization = globex
  p.price_cents = 119900
  p.status = :active
  p.description = "Samsung flagship with S Pen, 200MP camera, and AI features."
  p.metadata = {brand: "Samsung", year: 2025}
end

products << Catalog::Product.find_or_create_by!(name: "Vintage Denim Jacket") do |p|
  p.category = clothing
  p.user = carol
  p.organization = globex
  p.price_cents = 8999
  p.status = :active
  p.description = "Classic denim jacket with a modern fit."
end

products << Catalog::Product.find_or_create_by!(name: "The Art of Programming") do |p|
  p.category = books
  p.user = dave
  p.organization = globex
  p.price_cents = 4999
  p.status = :draft
  p.description = "Comprehensive guide to software craftsmanship."
end

# Variants
puts "Creating variants..."
products.first(4).each do |product|
  ["64GB", "128GB", "256GB"].each_with_index do |variant_name, i|
    Catalog::Variant.find_or_create_by!(product: product, sku: "#{product.name.parameterize}-#{variant_name.downcase}") do |v|
      v.name = variant_name
      v.price_cents = product.price_cents + (i * 10000)
      v.stock_count = rand(0..50)
    end
  end
end

# Product Details
products.first(3).each do |product|
  Catalog::ProductDetail.find_or_create_by!(product: product) do |d|
    d.specifications = "Weight: #{rand(100..500)}g\nDimensions: #{rand(10..20)}x#{rand(5..10)}x#{rand(0.5..2.0).round(1)}cm"
    d.warranty_info = "#{[1, 2, 3].sample}-year manufacturer warranty included."
  end
end

# Reviews
puts "Creating reviews..."
products.select(&:active?).each do |product|
  [alice, bob, carol, dave].sample(rand(1..3)).each do |user|
    Catalog::Review.find_or_create_by!(product: product, user: user) do |r|
      r.title = ["Great product!", "Solid purchase", "Exceeded expectations", "Good value", "Would recommend"].sample
      r.body = ["Excellent quality and fast shipping.", "Works exactly as described.", "Very happy with this purchase.", "Good for the price."].sample
      r.rating = rand(3..5)
      r.verified = [true, true, false].sample
    end
  end
end

# Comments on products (polymorphic)
products.select(&:active?).first(2).each do |product|
  Comment.find_or_create_by!(commentable: product, user: [alice, bob].sample) do |c|
    c.body = "Is this still available? Looks great!"
  end
end

puts ""
puts "Seeding complete!"
puts "  #{Admin.count} admins"
puts "  #{User.count} users"
puts "  #{Organization.count} organizations"
puts "  #{OrganizationUser.count} memberships"
puts "  #{Blogging::Post.count} blog posts (#{Blogging::Article.count} articles, #{Blogging::Tutorial.count} tutorials)"
puts "  #{Blogging::Tag.count} tags"
puts "  #{Comment.count} comments"
puts "  #{Catalog::Category.count} categories"
puts "  #{Catalog::Product.count} products"
puts "  #{Catalog::Variant.count} variants"
puts "  #{Catalog::Review.count} reviews"
puts ""
puts "Login credentials:"
puts "  Admin:  admin@plutonium.dev / password123"
puts "  Users:  alice@acme.com, bob@acme.com, carol@globex.com, dave@globex.com / password123"
