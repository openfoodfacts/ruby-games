require 'sinatra'
require 'json'

# Processing

# https://world.openfoodfacts.org/contributor/hungergames
OPENFACTS_ANONYMOUS_USER_ID ||= ENV.fetch('OPENFACTS_ANONYMOUS_USER_ID', 'hungergames')
OPENFACTS_ANONYMOUS_USER_PASSWORD ||= ENV.fetch('OPENFACTS_ANONYMOUS_USER_PASSWORD')

# TODO: Add openbeautyfacts
OPENFACTS_AVAILABLE_PROJECTS ||= %w{
  openfoodfacts
}

OPENFACTS_PROJECTS ||= [ENV.fetch('OPENFACTS_PROJECTS', OPENFACTS_AVAILABLE_PROJECTS.join(',')).
                        split(',').map(&:strip)].flatten &
                          OPENFACTS_AVAILABLE_PROJECTS

OPENFACTS_PROJECTS.each do |project|
  require project
end

OPENFACTS_LIBS ||= OPENFACTS_PROJECTS.map do |project|
  Object.const_get(project.capitalize)
end

OPENFACTS_AVAILABLE_LOCALES ||= OPENFACTS_LIBS.map { |lib|
  lib::Locale.all.map { |locale| locale['code'] }
}.inject { |available_locales, lib_codes|
  available_locales &= lib_codes
} + ['world']

OPENFACTS_LOCALE ||= ([ENV.fetch('OPENFACTS_LOCALE', 'world')] &
                          OPENFACTS_AVAILABLE_LOCALES).first

OPENFACTS_PER_PAGE ||= 20

lib = OPENFACTS_LIBS.first

product_states = lib::ProductState.all(locale: OPENFACTS_LOCALE)
product_state = product_states.detect { |ps| ps.name == 'Quantity to be completed' }

# https://world.openfoodfacts.org/state/quantity-to-be-completed/state/photos-validated
product_state.url = "#{product_state.url}/state/photos-validated"
product_state.products_count = 11_145 # TODO
# https://world.openfoodfacts.org/state/quantity-to-be-completed/state/photos-uploaded
#product_state.products_count = 65_000 # TODO

products_count = product_state.products_count

post '/api/update' do
  lib = OPENFACTS_LIBS.first

  product = lib::Product.get(params[:code])
  product.quantity = params[:quantity]

  user = lib::User.new(
    user_id: OPENFACTS_ANONYMOUS_USER_ID,
    password: OPENFACTS_ANONYMOUS_USER_PASSWORD
  )

  product.update(user: user)

  'ok'
end

IMAGE_KEYS ||= ['image_front_url', 'image_ingredients_url', 'image_nutrition_url']
def product_ok_for_completion?(product)
  (product.code && product.code != "") && # Has code
  (product.product_name && product.product_name != "") && # Has name
  (product.images && IMAGE_KEYS.any? { |image_key| product[image_key] }) &&

  (!product.quantity) # Has no quantity
end

get '/api/products_with_quantity_to_be_completed.json' do
  return [].to_json if products_count.zero?

  good_product = nil
  pages_count = (products_count / OPENFACTS_PER_PAGE.to_f).ceil
  begin
      random_page = pages_count > 1 ? rand(1..pages_count - 1) : 1
      # From lastest to older edited product
      puts "random_page #{random_page} #{product_state.url}/#{random_page}"

      products_for_state_page = product_state.products(page: random_page)
      # return products_for_state_page.to_json

      begin
        product = products_for_state_page.pop
        break if product.nil?

        product.fetch
        good_product = product if product_ok_for_completion?(product)
      end while good_product.nil?
  end while good_product.nil?

  return good_product.merge(url: good_product.url).to_json
end
