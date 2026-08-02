# 1. Hafif bir Node.js imajı seçiyoruz (Terraform ile uyumlu)
FROM node:18-alpine

# 2. Konteyner içindeki çalışma dizinini belirliyoruz
WORKDIR /app

# 3. Önce sadece paket listelerini kopyalıyoruz (Önbelleği verimli kullanmak için)
COPY package*.json ./

# 4. Gerekli kütüphaneleri (express, mssql vs.) kuruyoruz
RUN npm install

# 5. Tüm proje dosyalarını (server.js vb.) kopyalıyoruz
COPY . .

# 6. Dışarıya açılacak portu belirtiyoruz
EXPOSE 3000

# 7. Konteyner çalıştığında verilecek komut
CMD ["node", "server.js"]