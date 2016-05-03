script_name = "QC to Notes v1"
script_description = "Usa um ficheiro de CQ para facilitar a alteração das linhas."
script_author = "fmmagalhaes"
script_version = "1"

include("karaskel.lua")
--re = require 'aegisub.re'

function changeFile()

	function toMilli(hour, minute, second)
		return (hour * 60 + minute + second/60)*60000
	end

	qc_txt = aegisub.dialog.open('Selecione um ficheiro de sugestões (CQ)', '', '',
                               'Documentos de texto (.txt)|*.txt', false, true)
							   
	if qc_txt == nil then
		aegisub.cancel()
	end
							   
	-- Opens a file in read mode
	file = io.open(qc_txt, "r")

	-- makes corrections to all lines in file
	string1 = (file:read("*a")):gsub("(%d)[%p ](%d)","%1:%2"):gsub("%[(%d)","%1"):gsub("(%d)%]","%1")
	--string1 = re.sub(string1, "(\\[)?(\\d)(\\])?", "$2")
	-- Closes File
	file:close()

	--
	file = io.open("tmpinput.txt","w")
	file:write(string1) -- writes corrected input file in another file
	file:close()

	--
	file = io.open("tmpinput.txt","r") -- opens the "another file" to read from

	-- deletes every text in file
	qc_final_form = io.open("finalInput.txt" , "w")
	qc_final_form:write("") 
	qc_final_form:close()
	--

	qc_final_form = io.open("finalInput.txt","a+") -- opens a third file to write to in append mode, with all corrections applied

	for linha in file:lines() do -- iterates all lines in tmpinput.txt

		-- applies changes to the string that contains the current line
		string2 = linha:gsub("^(%d):", "0%1:"):gsub(":(%d)(%D)", ":%10%2"):gsub(":(%d)$", ":%10")
		string2 = string2:gsub("(:%d%d)$", "%1 ") -- caso da linha não ter sugestões
		string2 = string2:gsub("^(%d%d:%d%d)[^:]", "00:%1 ")
		if not (string2:match("^%d%d:%d%d:%d%d")==nil) then -- NÃO FUNCIONA SEM ISTO
			-- 00:12:20 --> 7939998 00:12:20
			--para futuramente se poder aceder à linha de ms correspondentes e também imprimir o tempo na forma humana em caso de falha
			string2 = string2:gsub("^(%d%d:%d%d:%d%d)", toMilli(string2:sub(1,2), string2:sub(4,5), string2:sub(7,8)).." %1")
		end
	  
		-- adds to finalInput.txt the changed current line
		qc_final_form:write(string2.."\n")
		print(string2)
	   
	end

	file:close()
	os.remove("tmpinput.txt")
	qc_final_form:close()

end

function applyQC(subtitles)
	--[[
	qc_txt = nil
	temp = nil
	qc_final_form = nil
	file = nil
	--]]
	changeFile()
	input = io.open("finalInput.txt", "r")
	--local selection = {}
	local line_counter = 1
	local notes = 0
	local failed_notes = 0
	local no_timing_lines = 0
	local is_this_note_repeated = false
	local repeated_notes = 0
	local error_obs = ""
	dialog_config=
		{
		    {
			class="label",
			x=0,y=0,width=1,height=1,
			label="Nome do Controlador de Qualidade:"
			},
			
			{
			class="edit",name="qcername",
			x=0,y=1,width=1,height=1,
			value=""
			}
		}

	pressed, result_table = aegisub.dialog.display(dialog_config, {"OK", "Cancelar"})
	if pressed == "Cancelar" then
		aegisub.cancel()
	end
	
	qcer_name = result_table.qcername:gsub("^([^()])", " - " .. "%1")
	-- se for "Username", vai ficar " - Username"
	-- se for "", fica ""
	
	--[[	
	error_reporting = aegisub.dialog.save('Guardar ficheiro de relatório de erros como', '', '', 'Documentos de texto (.txt)|*.txt', false)	
	
	if error_reporting == nil then
		aegisub.cancel()
	end
	--]]
		
	error_reporting = "CQ"..qcer_name.." - Relatório de erros"..".txt"
	output = io.open(error_reporting, "w")
	output:write("")
	output:close()
	output = io.open(error_reporting, "a+")
	for file_line in input:lines() do
		is_this_note_repeated = false
		if file_line:match("^%d+") then
			correction_time = tonumber(file_line:match("^%d+"))
			for i = 1, #subtitles do
				line = subtitles[i]
				if line.class == "dialogue" then
					if correction_time >= line.start_time - tonumber(tostring(line.start_time):sub(-3)) and correction_time <= line.end_time + 1000 - tonumber(tostring(line.end_time):sub(-3)) - 1 then
						line.text = line.text.."{CQ"..qcer_name..":"..file_line:gsub("^%d+",""):gsub("^ %d%d:%d%d:%d%d", "").."}"
						-- para teste:
						--line.text = line.start_time .." "..line.start_time - tonumber(tostring(line.start_time):sub(-3)) .. " "..line.end_time .." ".. line.end_time + 1000 - tonumber(tostring(line.end_time):sub(-3))
						subtitles[i] = line
						line_counter = i
						
						if not is_this_note_repeated then
							notes = notes + 1
						else
							repeated_notes = repeated_notes + 1
						end
						
						is_this_note_repeated = true
						--table.insert(selection, i)
					else
						if i == #subtitles and not is_this_note_repeated then
							failed_notes = failed_notes + 1
							error_obs = file_line:gsub("^%d+","") -- tira os milissegundos
							error_obs = error_obs:gsub("^ (%d%d:%d%d:%d%d)", "[%1]") -- mete o tempo dado em modo ksub
							aegisub.log("A nota \""..error_obs.."\" não encontrou tempo correspondente.\n")
							output:write(error_obs.."\n")
						end
					end
				end
			end
		else
			if (not file_line:match("# total lines:")) and (not file_line:match("^ *$")) then
				output:write(file_line.."\n")
				no_timing_lines = no_timing_lines + 1
			end
		end
	end
	input:close()
	os.remove("finalInput.txt")
	output:write("Total de observações falhadas obtidas de "..qc_txt.." = "..failed_notes + no_timing_lines..".")
	output:close()
	if notes == 1 then
		aegisub.log("Foi adicionada 1 observação ")
	else
		aegisub.log("Foram adicionadas "..notes.." observações ")
	end
	
	if failed_notes == 1 then
		aegisub.log("e falhou 1")
	else
		aegisub.log("e falharam "..failed_notes)
	end
	
	if no_timing_lines == 0 then
		aegisub.log(".")
	elseif no_timing_lines == 1 then
		aegisub.log(", para além de "..no_timing_lines.." observação sem tempo.")
	else
		aegisub.log(", para além de "..no_timing_lines.." observação sem tempo.")
	end

	if repeated_notes ~=0 then
		if repeated_notes == 1 then
			aegisub.log("\nDo número de observações adicionadas referido, 1 foi adicionada mais de uma vez, devido à existência de mais de uma linha no tempo mencionado.")
		else
			aegisub.log("\nDo número de observações adicionadas referido, ".. repeated_notes.." foram adicionadas mais de uma vez, devido à existência de mais de uma linha nos tempos mencionados.")
		end
	end
	
	aegisub.log("\n\nVerifique se "..notes + failed_notes.." é o total de sugestões em \""..qc_txt.."\".\nAs observações sem tempos correspondentes no ficheiro de legendas foram adicionadas a \""..error_reporting.."\", que está na mesma diretoria.")
	aegisub.log("\n\nPara fazer uso do programa, carregue \"Fechar\" e depois faça Ctrl+F e procure por \"CQ\". Assim, encontrará as linhas às quais foram adicionadas observações.")
	aegisub.log(" Para apagar essas observações posteriormente, corra de novo a automatização, mas desta vez selecione \"Eliminar notas geradas\".")
end

function deleteGeneratedNotes(subtitles)
	--local selected = {}
	for i = 1, #subtitles do
		line = subtitles[i]
		if line.class == "dialogue" then
			line.text = line.text:gsub("%{CQ[^%}]+}", "")
			subtitles[i] = line
		   -- table.insert(selected, i)
		end
	end
	--os.remove(error_reporting) Isto só funciona se o utilizador "Aplicar CQ" e não fechar o ficheiro de legendas antes de "Eliminar notas geradas"
	--return selected
end

function main(subtitles)

	dialog_config=
	{
		{
			class="dropdown",name="select",
			x=0,y=0,width=1,height=1,
			items={"Aplicar CQ","Eliminar notas geradas"},
			value="Aplicar CQ"
		}
	}

	pressed, result_table = aegisub.dialog.display(dialog_config, {"OK", "Cancelar"})

	if pressed == "Cancelar" then
		aegisub.cancel()
	end
		
	if result_table.select == "Eliminar notas geradas" then
		deleteGeneratedNotes(subtitles)
	else
		applyQC(subtitles)
	end

		
end

aegisub.register_macro(script_name, script_description, main)