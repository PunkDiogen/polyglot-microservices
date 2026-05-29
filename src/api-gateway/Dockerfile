FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /app
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /out

FROM mcr.microsoft.com/dotnet/aspnet:9.0
RUN adduser --system --group appuser
WORKDIR /app
COPY --from=build /out .
RUN chown -R appuser:appuser /app
USER appuser
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 5000

ENTRYPOINT ["./ApiGateway"]