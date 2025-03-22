# Instalador traccar com Mysql
Auto Install Traccar

Auto instalação do Traccar em sua última versão com driver mysql

Entre no seu servidor Linux, e execute essa unica linha abaixo.

```bash
wget https://raw.githubusercontent.com/tonnybarros/instalar-traccar/main/instalador_traccar.sh && chmod +x instalador_traccar.sh && ./instalador_traccar.sh
```

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

Teste efetuados em servidor Hetzner com Ubuntu 20.04
