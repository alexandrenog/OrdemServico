require 'sqlite3'
require "readline"
require 'rb-readline'
require 'Date'

module RbReadline
  def self.prefill_prompt(str)
    @rl_prefill = str.to_s
    @rl_startup_hook = :rl_prefill_hook
  end

  def self.rl_prefill_hook
    rl_insert_text @rl_prefill if @rl_prefill
    @rl_startup_hook = nil
  end
end
class ProgramaOS
	def initialize
		bd_init
		textos_define
		operacoes_define
		@senhaUsuario="banana"
	end
	def le texto = ">> ", error = false
		puts "Entrada invalida. Digite novamente!" if error
		print texto; return gets.chomp
	end
	def email_correto email
		(email =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)!=nil
	end
	def texto_eh_numero texto
		((texto=~ /\A\d+\z/) ? (true) : (false))
	end
	def texto_eh_data texto
		d, m, y = texto.split '-'
		return Date.valid_date?(y.to_i, m.to_i, d.to_i)
	end
	def bd_init
		@bancoDados = SQLite3::Database.new('empresa.database')
		@bancoDados.execute "create table if not exists Cliente (id integer primary key, nome text not null, telefone text not null, "+
						  "email text not null, documentos integer not null);"
		@bancoDados.execute "create table if not exists Funcionario (id integer primary key, nome text not null, telefone text not null, "+
						  "email text not null, documentos integer not null);"
		@bancoDados.execute "create table if not exists OrdemServico (id integer primary key, id_cliente integer not null, "+
							"id_funcionario integer not null, descricao_servico text not null, data_solicitacao date not null, "+
							"previsao_conclusao date not null);"
	end
	def pesquisaTabela tipo_dado, info
		return @bancoDados.execute("select * from #{tipo_dado} ") if info == nil
		return @bancoDados.execute("select * from #{tipo_dado} where id = #{info[:id]}") if info[:id]!=nil
		return @bancoDados.execute("select * from #{tipo_dado} where nome like '%#{info[:nome]}%'") if info[:nome]!=nil
		return @bancoDados.execute("select * from #{tipo_dado} where id_cliente like '%#{info[:id_cliente]}%'") if info[:id_cliente]!=nil
		return []
	end
	def printLinhaBD linha, campos, tipo_dado
		case tipo_dado
		when "Cliente", "Funcionario"
			str = "ID: #{linha[0]}"
			(1...linha.size).map{|idx| str<<(", "+campos[idx-1].to_s+": #{linha[idx]}")}
		when "OrdemServico"
			str = "Numero da OS: #{linha[0]}\t\t"
			cliente = pesquisaTabela("Cliente",{id: linha[1]}).first
			str << "Cliente[#{linha[1]}]: #{cliente[1]}\t\t"
			funcionario = pesquisaTabela("Funcionario",{id: linha[2]}).first
			str << "Funcionario[#{linha[2]}]: #{funcionario[1]}\n"
			str << "Data de Solicitacao: #{linha[4]}\t\tPrevisao de Conclusao: #{linha[5]}\n"
			str << "Descricao do Servico: #{linha[3]}\n"
		end
		puts str
	end
	def textos_define
		@menuTexto = "Cliente: %d_Cadastrar %d_Editar %d_Buscar %d_Excluir %d_Listar\n"
		@menuTexto << "Funcionario: %d_Cadastrar %d_Editar %d_Buscar %d_Excluir %d_Listar\n"
		@menuTexto << "Ordem de Servico: %d_Cadastrar %d_Editar %d_Buscar %d_Excluir %d_Listar\nX_Sair"
		@menuTexto = @menuTexto % (1..15).to_a
		@atributosPessoa= %w(nome telefone email documentos)
		@atributosOS= %w(id_cliente id_funcionario descricao_servico data_solicitacao previsao_conclusao)
	end
	def operacoes_define
		executa_autenticando = ->(block){
			senha=le("Digite a sua senha: ")
			if senha == @senhaUsuario
				block.call
			else
				puts "Senha Incorreta!"
			end
		}
		cadastro=->(tipo_dado,atributos){
			lambda(){
				puts "Cadastrar #{tipo_dado}\n"
				valores=[]
				atributos.each{|campo|
					texto = "Insira o valor do [#{campo}]: "
					texto = texto[0..-3].concat("(DD-MM-YYYY): ") if ["data_solicitacao", "previsao_conclusao"].include?(campo) 
					valor=le(texto)
					case campo
					when "email"
						while !email_correto(valor); valor=le(texto, true); end
					when "documentos", "id_cliente", "id_funcionario"
						while !texto_eh_numero(valor); valor=le(texto, true); end
						valor=valor.to_i
					when "data_solicitacao", "previsao_conclusao"
						while !texto_eh_data(valor); valor=le(texto, true); end
					end
					valores << valor
				}
				executa_autenticando.call(lambda{
						puts "#{tipo_dado} cadastrado com sucesso!"
						if ["Cliente", "Funcionario"].include?(tipo_dado)
						@bancoDados.execute "insert into #{tipo_dado}(#{atributos.join(', ')}) "+
											"values ('#{valores[0]}','#{valores[1]}','#{valores[2]}',#{valores[3]})"
						elsif tipo_dado == "OrdemServico"
						@bancoDados.execute "insert into #{tipo_dado}(#{atributos.join(', ')}) "+
											"values (#{valores[0]},#{valores[1]},'#{valores[2]}','#{valores[3]}','#{valores[4]}')"
						end
				})
			}
		}
		edicao=->(tipo_dado,atributos){
			lambda(){
				dado = pesquisaTabela(tipo_dado,{id: le("Editar #{tipo_dado}\nID: ")}).first
				return if dado == nil
				valores=[]
				atributos.each_with_index{|campo,idx|
					RbReadline.prefill_prompt(dado[idx+1])
					texto = "Edite o valor do campo [#{campo}]: "
					texto = texto[0..-3].concat("(DD-MM-YYY): ") if ["data_solicitacao", "previsao_conclusao"].include?(campo) 
					valor = Readline.readline(texto, true)
					case campo
					when "email"
						while !email_correto(valor); valor=le(texto, true); end
					when "documentos", "id_cliente", "id_funcionario"
						while !texto_eh_numero(valor); valor=le(texto, true); end
						valor=valor.to_i
					when "data_solicitacao", "previsao_conclusao"
						while !texto_eh_data(valor); valor=le(texto, true); end
					end
					valores<<valor
				}
				executa_autenticando.call(lambda{
					set = atributos.map.with_index{|e,i|
						if valores[i].is_a?(String)
							"#{e}='#{valores[i]}'"
						elsif valores[i].is_a?(Integer)
							"#{e}=#{valores[i]}"
						end
					}.join(", ")
					@bancoDados.execute "update #{tipo_dado} set #{set} where id = #{dado[0]}"
					puts "#{tipo_dado} atualizado com sucesso!"
				})
			}
		}
		pesquisa=->(tipo_dado,atributos){
			lambda(){
				case tipo_dado
				when "Cliente", "Funcionario"
					nome = le("Nome: ")
					pesquisaTabela(tipo_dado,{nome: nome}).each{|dado| printLinhaBD(dado, atributos, tipo_dado)}
				when "OrdemServico"
					info_cliente=le("ID/Nome do Cliente: ")
					if texto_eh_numero(info_cliente)
						pesquisaTabela(tipo_dado,{id_cliente: id_cliente}).each{|dado| printLinhaBD(dado, atributos, tipo_dado)}
					else
						id_cliente = pesquisaTabela("Cliente",{nome: info_cliente}).first[0] # id do cliente
						pesquisaTabela(tipo_dado,{id_cliente: id_cliente}).each{|dado| printLinhaBD(dado, atributos, tipo_dado)}
					end
				end
				print "Pesquisa Finalizada!"
			}
		}
		exclusao=->(tipo_dado,atributos){
			lambda(){
				dado = pesquisaTabela(tipo_dado,{id: le("Excluir #{tipo_dado}\nID: ")}).first
				return if dado == nil
				printLinhaBD(dado, atributos, tipo_dado)
				certeza=le("Tem certeza que quer excluir o #{tipo_dado}?(s/n) ")
				while(certeza.downcase!="s" and certeza.downcase !="n")
					certeza=le("Tem certeza que quer excluir o #{tipo_dado}?(s/n) ")
				end
				break if certeza.downcase =="n"
				executa_autenticando.call(lambda{
					puts "#{tipo_dado} excluido com sucesso!"
					@bancoDados.execute "delete from #{tipo_dado} where id = #{dado[0]}"
				})
			}
		}
		listar=->(tipo_dado,atributos){
			lambda(){
				pesquisaTabela(tipo_dado,nil).each{|dado| printLinhaBD(dado, atributos, tipo_dado)}
			}
		}
		@operacoesMenu=[]
		{"Cliente" => @atributosPessoa,"Funcionario" => @atributosPessoa,"OrdemServico" => @atributosOS}.each do |tipo_dado, atributos|
			@operacoesMenu<<cadastro.call(tipo_dado,atributos)
			@operacoesMenu<<  edicao.call(tipo_dado,atributos)
			@operacoesMenu<<pesquisa.call(tipo_dado,atributos)
			@operacoesMenu<<exclusao.call(tipo_dado,atributos)
			@operacoesMenu<<  listar.call(tipo_dado,atributos)
		end
		@operacoesMenu<<lambda{exit}
	end
	def run
		while true
			print @menuTexto, "\nOpcao: "
			idx=gets.to_i-1
			system "cls"
			break if !(0...@operacoesMenu.size).include?(idx) or @operacoesMenu[idx].call == false
			system("stty raw -echo"); STDIN.getc
			system "cls"
		end
	end
end

prg = ProgramaOS.new
prg.run