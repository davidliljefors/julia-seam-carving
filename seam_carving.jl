### A Pluto.jl notebook ###
# v0.12.3

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ cc88efd0-0d3b-11eb-2e26-45aaf8c106e9
using Images, ImageView, ImageFiltering, Statistics, ImageMagick, PlutoUI

# ╔═╡ bacb2620-11e9-11eb-29e4-eb65e6601325
md"# Seam Carving in Julia"

# ╔═╡ b67963f2-1204-11eb-3188-8f29213b5d36
path_to_image = "fox.jpg"

# ╔═╡ af148ba0-11ee-11eb-2e99-9fdb8572cdd1
md"# Functions"

# ╔═╡ d07ad360-0d4f-11eb-0dba-a732b6aae9fa
# Convert RGB to brigthness
function brightness(img_element::AbstractRGB)
	return mean((img_element.r + img_element.g + img_element.b))
end

# ╔═╡ eeda49c0-0d50-11eb-3bf7-491ef4dd88ad
# Find energy, how important a pixel is to the image.
function find_energy(img)
	energy_x = imfilter(brightness.(img), Kernel.sobel()[2])
	energy_y = imfilter(brightness.(img), Kernel.sobel()[1])
	
	return sqrt.(energy_x.^2 + energy_y.^2)
end

# ╔═╡ 646d1eb0-0d5b-11eb-3b93-53b9cbcd6568
# To help view energy image, normalize values to 0-1
function normalize_greyness(array)
	max, _ = findmax(array)
	array = array./max
	return array
end

# ╔═╡ cc570100-0d54-11eb-3567-f92edb0103e4
# Convert a value to RGB to view arrays as images
function grey_to_rgb(brigthness)::RGB
	return RGB(brigthness, brigthness, brigthness)
end

# ╔═╡ c4d15310-0d66-11eb-2583-e95f2789891a
# Finds the seam of least energy starting at given position
function find_seam_at(next_elements, element)
	seam = zeros(Int, size(next_elements)[1])
	seam[1]	= element
	
	for i = 2 :length(seam)
		seam[i] = seam[i-1] + next_elements[i, seam[i-1]]
	end
	
	return seam
end

# ╔═╡ fd47f780-0d57-11eb-08df-4d70a66c32fe
# Calculate the combined energy needed for each pixel from bottom to top
function find_energy_map(energy)
	energy_map = zeros(size(energy))
	energy_map[ end, : ] = energy[ end, : ]
	
	next_elements = zeros(Int, size(energy))
	
	for i = size(energy)[1]-1 :-1:1
		for j = 1 :size(energy)[2]
			left = max(1, j-1)
			right = min(j+1, size(energy)[2])
			
			local_energy, next_element = findmin(energy_map[i+1, left:right])
			energy_map[i,j] = local_energy + energy[i,j]
			
			next_elements[i,j] = next_element - 2
			
			if left == 1
				next_elements[i,j] += 1
			end
		end
	end
	
	return energy_map, next_elements
end

# ╔═╡ fbc4e440-0df7-11eb-32e4-41501f4705e0
# Finds the best starting point and the seam from there
function find_seam(energy)
	energy_map, next_elements = find_energy_map(energy)
	
	_, min_element = findmin(energy_map[1, :])
	
	return find_seam_at(next_elements, min_element)
end

# ╔═╡ 56cb51d0-0d67-11eb-020a-ed2e89d3626c
function draw_seam(image, seam)
	image_with_seam = copy(image)
	for i = 1 : size(image_with_seam)[1]
		image_with_seam[i, seam[i]] = RGB(1, 0, 0)
	end
	
	return image_with_seam
end

# ╔═╡ dbba4400-0df8-11eb-2e20-c51081020bb7
function remove_seam(img, seam)
	img_res = (size(img)[1], size(img)[2]-1)
	
	new_img = Array{RGB}(undef, img_res)
	
	for i = 1 :length(seam)
		if seam[i] > 1 && seam[i] < size(img)[2]
			new_img[i, :] .= vcat(img[i, 1:seam[i]-1], img[i, seam[i]+1:end])
		elseif seam[i] == 1
			new_img[i, :] .= img[i, 2:end]
		elseif seam[i] == size(img)[2]
			new_img[i, :] .= img[i, 1:end-1]
		end
	end
	return new_img
end

# ╔═╡ 87bcf410-0df8-11eb-2daf-538cfa814076
function seam_carving(img, res)
	if res < 0 || res > size(img)[2]
		error("resolution not acceptable")
	end
	
	for i = (1:size(img)[2] - res)
		energy = find_energy(img)
		seam = find_seam(energy)
		img = remove_seam(img, seam)
	end
	return img
end

# ╔═╡ 63ad1080-0dff-11eb-1c35-1bfe4f50b2d2
# Make all carved variants of the original image
function get_all_carved(img, amount)
	
	if(amount < 0 || amount > size(img)[2])
		error("amount not acceptable")
	end
	
	all_images = []
	
	for i = (1:amount)
		energy = find_energy(img)
		seam = find_seam(energy)
		img = remove_seam(img, seam)
		push!(all_images,  img)
	end
	return all_images
end

# ╔═╡ bdd45530-11ee-11eb-2f66-e5702f13faec
md"# Examples"

# ╔═╡ 1477a9be-11ed-11eb-1c09-7b7b7533bc4c
Text("The original image")

# ╔═╡ 365a0480-0d3c-11eb-3be9-b936bc1c24e1
begin
	test_image = imresize(load(path_to_image), ratio=1/4.5)
	test_image = RGB{Float32}.(test_image)
end

# ╔═╡ 4adfbc30-0e3e-11eb-0337-0930e5eb5840
size(test_image)

# ╔═╡ 20069860-0d50-11eb-1992-d774528dedc2
energy = find_energy(test_image)

# ╔═╡ 2e4124a2-11eb-11eb-2b46-2b85dcceb40e
Text("This image below shows the \"energy\" or how important each pixel is")

# ╔═╡ 0d167950-0d55-11eb-2c9c-c1b4e99785e3
energy_image = grey_to_rgb.(energy)

# ╔═╡ 01f2c56e-0d59-11eb-27f2-15d903ff9441
energy_map, next_elements = find_energy_map(energy)

# ╔═╡ 849cfe00-11eb-11eb-071c-ab70e72bf6f5
Text("This image below shows the the combined energy needed for a pixel at that position.")

# ╔═╡ 3f906450-0d59-11eb-21ba-178ba8b71275
begin
	normalized = normalize_greyness(energy_map)
	energy_map_img = grey_to_rgb.(normalized)
end

# ╔═╡ 43778950-0df8-11eb-1cf1-eb7ba89e78e3
best_seam = find_seam(energy)

# ╔═╡ ae3a1180-11eb-11eb-2624-cbfe3592cec9
Text("Here the first best seam marked in red")

# ╔═╡ 51e33f70-0df8-11eb-2627-317c7ed7c508
image_with_best_seam = draw_seam(test_image, best_seam)

# ╔═╡ d6bd64d0-0dff-11eb-14a9-bb38e6821169
begin
	max_reduction = size(test_image)[2] * 0.3
	all_carved_images = get_all_carved(test_image, max_reduction)
end

# ╔═╡ 921f64b0-0dfd-11eb-2f36-6315c0dd1c8e
begin
	width = length(all_carved_images)
@bind new_width Slider(1:width, default=1, show_value=true)
end

# ╔═╡ 258a0da0-0e02-11eb-0cf1-d74bed88538b
all_carved_images[new_width]

# ╔═╡ dc50f700-0dfe-11eb-3cc9-0fc42ab218f5
test_image

# ╔═╡ Cell order:
# ╟─bacb2620-11e9-11eb-29e4-eb65e6601325
# ╟─b67963f2-1204-11eb-3188-8f29213b5d36
# ╟─af148ba0-11ee-11eb-2e99-9fdb8572cdd1
# ╠═cc88efd0-0d3b-11eb-2e26-45aaf8c106e9
# ╠═d07ad360-0d4f-11eb-0dba-a732b6aae9fa
# ╠═eeda49c0-0d50-11eb-3bf7-491ef4dd88ad
# ╠═646d1eb0-0d5b-11eb-3b93-53b9cbcd6568
# ╠═cc570100-0d54-11eb-3567-f92edb0103e4
# ╠═c4d15310-0d66-11eb-2583-e95f2789891a
# ╠═fbc4e440-0df7-11eb-32e4-41501f4705e0
# ╠═fd47f780-0d57-11eb-08df-4d70a66c32fe
# ╠═56cb51d0-0d67-11eb-020a-ed2e89d3626c
# ╠═dbba4400-0df8-11eb-2e20-c51081020bb7
# ╠═87bcf410-0df8-11eb-2daf-538cfa814076
# ╠═63ad1080-0dff-11eb-1c35-1bfe4f50b2d2
# ╟─bdd45530-11ee-11eb-2f66-e5702f13faec
# ╟─1477a9be-11ed-11eb-1c09-7b7b7533bc4c
# ╠═365a0480-0d3c-11eb-3be9-b936bc1c24e1
# ╠═4adfbc30-0e3e-11eb-0337-0930e5eb5840
# ╠═20069860-0d50-11eb-1992-d774528dedc2
# ╟─2e4124a2-11eb-11eb-2b46-2b85dcceb40e
# ╠═0d167950-0d55-11eb-2c9c-c1b4e99785e3
# ╠═01f2c56e-0d59-11eb-27f2-15d903ff9441
# ╟─849cfe00-11eb-11eb-071c-ab70e72bf6f5
# ╠═3f906450-0d59-11eb-21ba-178ba8b71275
# ╠═43778950-0df8-11eb-1cf1-eb7ba89e78e3
# ╟─ae3a1180-11eb-11eb-2624-cbfe3592cec9
# ╠═51e33f70-0df8-11eb-2627-317c7ed7c508
# ╠═d6bd64d0-0dff-11eb-14a9-bb38e6821169
# ╠═921f64b0-0dfd-11eb-2f36-6315c0dd1c8e
# ╠═258a0da0-0e02-11eb-0cf1-d74bed88538b
# ╠═dc50f700-0dfe-11eb-3cc9-0fc42ab218f5
