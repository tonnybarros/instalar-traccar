# Instalador traccar com Mysql
Auto Install Traccar

Auto instalação do Traccar em sua última versão com driver mysql

Entre no seu servidor Linux, e execute essa unica linha abaixo.

```bash
wget https://raw.githubusercontent.com/tonnybarros/instalar-traccar/main/instalador_traccar.sh && chmod +x instalador_traccar.sh && ./instalador_traccar.sh
```

A instalação vai solicitar:
- Nome do banco de dados Mysql
- Usuário do banco de dados Mysql
- Senha do banco de dados Mysql
- Domínio para gerar o certificado SSL
- E se deseja alocar memória para o Java, o Traccar usa java, e recomenta que aloque de 50% a 80% de memória do servidor, caso esteja usando apenas o Traccar no servidor.
Leia mais aqui: https://www.traccar.org/optimization/
Caso não queria alocar memória, a instalação ao perguntar quanto deseja usar, apenas aperte o ENTER, a instalação vai identificar a falta desse parametro e não vai modificar o arquivo de serviço.

No final da instalação, pode gerenciar o Traccar executando no terminal assim:

iniciar-traccar (Iniciar o Traccar)

parar-traccar (Parar o Traccar)

status-traccar (Ver status do Traccar)

reiniciar-traccar (Reiniciar o Traccar)

log-traccar (Visualizar o log em tempo real) 
o mesmo que:
```bash
sudo tail -f /opt/traccar/logs/tracker-server.log
```

log-traccar-pesquisa (Visualizar o log em tempo real do termo específico) 
o mesmo que:
```bash
sudo tail -f /opt/traccar/logs/tracker-server.log | grep XXXX
```
Troque o xxxx pela palavra que deseja procurar no log em tempo real

editar-traccar (Visualizar o log em tempo real) 
o mesmo que:
```bash
sudo nano /opt/traccar/conf/traccar.xml
```

Teste efetuados em servidor Hetzner com Ubuntu 20.04 e 22.04

## Desenvolvedores

### Programador
- **Nome:** Tonny Barros
- **Email:** tonnybarros@gmail.com
- **Contato:** +55 21 97912-3851

### Colaborador
- **Nome:** Michaell Oliveira
- **Email:** michaelloliveira@gmail.com
- **Contato:** +55 79 9116-5245
