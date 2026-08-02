const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();

// Middleware: Dışarıdan (React'tan) gelen JSON verilerini okuyabilmek ve CORS engelini aşmak için
app.use(cors());
app.use(express.json());

// PostgreSQL Veritabanı Bağlantı Ayarları
const pool = new Pool({
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASS || 'A123456a*1',
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'tododb'
});

// --- YENİ EKLENEN KISIM: Veritabanı Başlangıç Ayarı ---
async function initializeDatabase() {
    try {
        const createTableQuery = `
            CREATE TABLE IF NOT EXISTS Todos (
                Id SERIAL PRIMARY KEY,
                TaskName VARCHAR(255) NOT NULL,
                IsCompleted BOOLEAN DEFAULT FALSE,
                CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `;
        await pool.query(createTableQuery);
        console.log("Veritabanı kontrolü tamamlandı: 'Todos' tablosu hazır.");
    } catch (err) {
        console.error("Veritabanı tablosu oluşturulurken hata:", err);
    }
}
// ------------------------------------------------------

// 1. GET: Tüm görevleri listele
app.get('/todos', async (req, res) => {
    try {
        let result = await pool.query("SELECT * FROM Todos ORDER BY CreatedAt DESC");
        res.json(result.rows);
    } catch (err) {
        console.error("Hata:", err);
        res.status(500).send("Sunucu hatası");
    }
});

// 2. POST: Yeni bir görev ekle
app.post('/todos', async (req, res) => {
    const { taskName } = req.body;

    if (!taskName) {
        return res.status(400).send("Görev adı boş olamaz!");
    }

    try {
        await pool.query(
            "INSERT INTO Todos (TaskName, IsCompleted) VALUES ($1, $2)",
            [taskName, false]
        );
        res.status(201).send("Görev başarıyla eklendi");
    } catch (err) {
        console.error("Hata:", err);
        res.status(500).send("Sunucu hatası");
    }
});

// 3. PUT: Görevin durumunu (Tamamlandı/Tamamlanmadı) güncelle
app.put('/todos/:id', async (req, res) => {
    const todoId = req.params.id;
    const { isCompleted } = req.body;

    try {
        await pool.query(
            "UPDATE Todos SET IsCompleted = $1 WHERE Id = $2",
            [isCompleted, todoId]
        );
        res.send("Görev güncellendi");
    } catch (err) {
        console.error("Hata:", err);
        res.status(500).send("Sunucu hatası");
    }
});

// 4. DELETE: Görevi sil
app.delete('/todos/:id', async (req, res) => {
    const todoId = req.params.id;

    try {
        await pool.query(
            "DELETE FROM Todos WHERE Id = $1",
            [todoId]
        );
        res.send("Görev silindi");
    } catch (err) {
        console.error("Hata:", err);
        res.status(500).send("Sunucu hatası");
    }
});

// Sunucuyu Başlat
const PORT = process.env.PORT || 3000;

// --- YENİ EKLENEN KISIM: Akıllı Başlangıç ve Tekrar Deneme (Retry) Mantığı ---
async function startServer() {
    let retries = 15; // 5 yerine 15 yaptık (Toplam 75 saniye bekleyebilir)
    
    while (retries > 0) {
        try {
            console.log("Veritabanına bağlanmaya çalışılıyor...");
            // PostgreSQL bağlantı testi
            await pool.query('SELECT NOW()');
            
            const createTableQuery = `
                CREATE TABLE IF NOT EXISTS Todos (
                    Id SERIAL PRIMARY KEY,
                    TaskName VARCHAR(255) NOT NULL,
                    IsCompleted BOOLEAN DEFAULT FALSE,
                    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            `;
            await pool.query(createTableQuery);
            console.log("HARİKA! Veritabanı bağlandı ve 'Todos' tablosu hazır.");
            
            app.listen(PORT, () => {
                console.log(`API Sunucusu http://localhost:${PORT} adresinde çalışıyor`);
            });
            
            break; 
            
        } catch (err) {
            console.error(`Veritabanı henüz hazır değil. 5 saniye sonra tekrar denenecek... (Kalan deneme: ${retries - 1})`);
            retries--;
            await new Promise(resolve => setTimeout(resolve, 5000));
        }
    }
    
    if (retries === 0) {
        console.error("KRİTİK HATA: Veritabanına ulaşılamadı. Sunucu başlatılamıyor.");
    }
}

startServer();

// app.listen(PORT, async () => {
//     console.log(\`API Sunucusu http://localhost:\${PORT} adresinde çalışıyor\`);
//     // Sunucu ayağa kalktığında tablo kontrol fonksiyonunu çağır
//     await initializeDatabase(); 
// });