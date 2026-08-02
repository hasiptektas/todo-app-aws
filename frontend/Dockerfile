# --- AŞAMA 1: İnşa (Build) Süreci ---
FROM node:20-alpine AS builder

WORKDIR /app

# Paketleri kopyala ve kur
COPY package*.json ./
RUN npm install

# Tüm React kodunu kopyala ve production (üretim) versiyonunu derle
COPY . .
RUN npm run build

# --- AŞAMA 2: Sunum (Production) Süreci ---
# Terraform'daki web servisimiz Nginx kullanıyordu, burada da aynısını yapıyoruz
FROM nginx:alpine

# Nginx'in varsayılan yayın klasörünü temizle
RUN rm -rf /usr/share/nginx/html/*

# Aşama 1'de (builder) derlenen 'dist' klasöründeki dosyaları Nginx'in içine kopyala
COPY --from=builder /app/dist /usr/share/nginx/html





# YENİ EKLENEN SATIR: Kendi Nginx ayar dosyamızı içeri kopyalıyoruz
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Nginx varsayılan olarak 80 portunda çalışır
EXPOSE 80

# Nginx'i ön planda çalıştır
CMD ["nginx", "-g", "daemon off;"]