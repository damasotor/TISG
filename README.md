>LINUX
- Ver los contenedores levantados
#### sudo docker ps

- Compilar proyecto y copiar .war al tomcat
#### sudo docker-compose build tomcat

- Detener contenedores
#### sudo docker-compose down

- Levantar contenedores
#### sudo docker-compose up -d

-   Comprobar estado local del postgresql (Para ver si esta usando el puerto)
##### sudo systemctl status postgresql

-  Detener el servicio
#### sudo systemctl stop postgresql

---
> WINDOWS
> Iniciar docker.desktop

- Ver los contenedores levantados
#### docker ps

- Compilar proyecto y copiar .war al tomcat
#### docker compose build tomcat

- Detener contenedores
#### docker compose down

- Levantar contenedores
#### docker compose up -d