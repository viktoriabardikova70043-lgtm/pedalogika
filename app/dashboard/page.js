"use client";
import { useEffect, useState } from "react";
import { supabase } from "../../lib/supabaseClient";

// Пример: этот запрос вернёт только учеников текущего залогиненного
// преподавателя — благодаря политике RLS "teacher sees own students"
// из supabase/schema.sql. Ученику или родителю тот же запрос вернёт
// только его собственные данные — фильтровать вручную не нужно.
export default function Dashboard() {
  const [students, setStudents] = useState([]);

  useEffect(() => {
    supabase.from("students").select("*").then(({ data, error }) => {
      if (!error) setStudents(data);
    });
  }, []);

  return (
    <div style={{ padding: 40 }}>
      <h1>Мои ученики</h1>
      <ul>
        {students.map((s) => <li key={s.id}>{s.name} — {s.grade}</li>)}
      </ul>
    </div>
  );
}
