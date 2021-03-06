class User < Cognito::ApplicationRecord
  has_many :user_pools
  has_many :pools, through: :user_pools

  def self.convert
    { 'Salutation' => :title, 'Last Name' => :last_name, 'Mobile' => :phone_number, 'Unique Number' => :primary_identifier, 'Campaign Code' => :pool_name }
  end

  def self.reset
    UserPool.delete_all
    Pool.delete_all
    User.delete_all
  end

  # User.load_csv('/home/admin/prudential.csv', true)
  def self.load_csv(file_name, create = false)
    CSV.foreach(file_name, { headers: true, header_converters: lambda { |name| convert[name] } }) do |row|
      if create
        pool = Pool.find_or_create_by(name: row[:pool_name] || 'unknown')
        row[:phone_number] = "+#{row[:phone_number]}"
        row = row.to_h.except(:pool_name)
        user = User.create(row)
        pool.users << user
      else
        puts "title: #{row[:title]} phone_number: #{row[:phone_number]} last_name: #{row[:last_name]} id: #{row[:primary_identifier]} pool: #{row[:pool_name]}"
      end
    end
  end
end
