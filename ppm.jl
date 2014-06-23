function save(name, img)
	open("$name", "w") do f
		w, h = size(img)
		write(f, collect(Uint8, "P6 $w $h 255\n"))
		for p in img
			psize = size(p, 1)
			if psize == 3
				write(f, uint8(p[1]))
				write(f, uint8(p[2]))
				write(f, uint8(p[3]))
			elseif psize == 1
				write(f, uint8(p))
				write(f, uint8(p))
				write(f, uint8(p))
			else
				error("Weird-dimensional object given to ppm.save. size(obj, 1) = $psize")
			end
		end
	end
end

function save_and_convert(name, img)
	save(name, img)
	outname = "$name.png"
	run(`convert ppm:$name png:$outname`)
	isfile(name) && rm(name)
	outname
end

function png_data(img)
	(ppmpath, _) = mktemp()
	(pngpath, _) = mktemp()
	save(ppmpath, img)
	run(`convert ppm:$ppmpath png:$pngpath`)

	f = open(pngpath)
	output = readbytes(f)
	close(f)
	isfile(ppmpath) && rm(ppmpath)
	isfile(pngpath) && rm(pngpath)
	output
end

function s(name::String, img)
	run(`mkdir -p output`)
	outname = save_and_convert("output/$name", img)
	run(`open $outname`)
end