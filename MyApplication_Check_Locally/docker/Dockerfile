# --- build stage -----------------------------------------------------------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build

COPY app/pom.xml .
RUN mvn -B dependency:go-offline 

COPY app/src ./src
RUN mvn -B clean package -DskipTests

# --- runtime stage -----------------------------------------------------------
# Tomcat 10.1 is required (not 9.x) because Spring Boot 3 uses the jakarta.*
# servlet namespace.
FROM tomcat:10.1-jdk17-temurin

RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=build /build/target/daily-journal.war /usr/local/tomcat/webapps/ROOT.war

RUN addgroup --system tomcat_grp && adduser --system --ingroup tomcat_grp tomcat_usr \
    && chown -R tomcat_usr:tomcat_grp /usr/local/tomcat
USER tomcat_usr

EXPOSE 8080
CMD ["catalina.sh", "run"]
