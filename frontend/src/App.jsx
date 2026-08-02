import { useState, useEffect } from 'react';

function App() {
  // Uygulama içindeki değişkenlerimiz (State)
  const [todos, setTodos] = useState([]);
  const [taskName, setTaskName] = useState('');

  // Node.js sunucumuzun adresi
  const API_URL = '/api/todos';

  // 1. GET: Sayfa ilk açıldığında görevleri getir
  useEffect(() => {
    fetchTodos();
  }, []);

  const fetchTodos = async () => {
    try {
      const response = await fetch(API_URL);
      const data = await response.json();
      setTodos(data);
    } catch (error) {
      console.error("Veri çekilemedi. Node.js sunucusu açık mı?", error);
    }
  };

  // 2. POST: Yeni görev ekle
  const addTodo = async (e) => {
    e.preventDefault(); // Sayfanın yenilenmesini engeller
    if (!taskName) return; // Boş kayıt eklemeyi önler

    try {
      await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ taskName })
      });
      setTaskName(''); // Eklemeden sonra input kutusunu temizle
      fetchTodos();    // Güncel listeyi tekrar çek
    } catch (error) {
      console.error("Görev eklenemedi:", error);
    }
  };

  // 3. PUT: Görevin durumunu değiştir (Checkbox tıklandığında)
  const toggleTodo = async (id, currentStatus) => {
    try {
      await fetch(`${API_URL}/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isCompleted: !currentStatus })
      });
      fetchTodos();
    } catch (error) {
      console.error("Durum güncellenemedi:", error);
    }
  };

  // 4. DELETE: Görevi sil
  const deleteTodo = async (id) => {
    try {
      await fetch(`${API_URL}/${id}`, {
        method: 'DELETE'
      });
      fetchTodos();
    } catch (error) {
      console.error("Görev silinemedi:", error);
    }
  };

  // Arayüz (HTML/JSX Kısmı)
  return (
    <div style={{ maxWidth: '500px', margin: '40px auto', fontFamily: 'sans-serif' }}>
      <h2>Yapılacaklar Listesi 📋</h2>

      <form onSubmit={addTodo} style={{ display: 'flex', marginBottom: '20px' }}>
        <input
          type="text"
          value={taskName}
          onChange={(e) => setTaskName(e.target.value)}
          placeholder="Yeni görev yazın..."
          style={{ flexGrow: 1, padding: '10px', fontSize: '16px' }}
        />
        <button type="submit" style={{ padding: '10px 20px', marginLeft: '10px', cursor: 'pointer' }}>
          Ekle
        </button>
      </form>

      <ul style={{ listStyleType: 'none', padding: 0 }}>
        {todos.map((todo) => (
          <li
            key={todo.id}
            style={{
              display: 'flex', alignItems: 'center', padding: '15px',
              marginBottom: '10px', border: '1px solid #ddd', borderRadius: '5px'
            }}
          >
            <input
              type="checkbox"
              checked={todo.iscompleted}
              onChange={() => toggleTodo(todo.id, todo.iscompleted)}
              style={{ transform: 'scale(1.5)', marginRight: '15px', cursor: 'pointer' }}
            />
            <span style={{
              flexGrow: 1, fontSize: '18px',
              textDecoration: todo.iscompleted ? 'line-through' : 'none',
              color: todo.iscompleted ? '#888' : '#000'
            }}>
              {todo.taskname}
            </span>
            <button
              onClick={() => deleteTodo(todo.id)}
              style={{ backgroundColor: '#ff4d4f', color: 'white', border: 'none', padding: '8px 12px', borderRadius: '4px', cursor: 'pointer' }}
            >
              Sil
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default App;