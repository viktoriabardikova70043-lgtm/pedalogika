-- ============================================================
-- PEDALOGIKA — схема базы данных (Supabase / PostgreSQL)
-- Запускать в Supabase: Project → SQL Editor → New query → Run
-- ============================================================

-- Роли пользователей выдаются через auth.users (Supabase Auth)
-- + таблицу profiles с полем role: 'teacher' | 'student' | 'parent'

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('teacher','student','parent')),
  full_name text,
  created_at timestamptz default now()
);

create table teachers (
  id uuid primary key references profiles(id) on delete cascade,
  phone text
);

create table students (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles(id) on delete set null, -- заполняется, когда у ученика появляется логин
  teacher_id uuid not null references teachers(id) on delete cascade,
  name text not null,
  age int,
  grade text,
  direction text,
  status text default 'active' check (status in ('active','archived')),
  start_date date,
  parent_request text,
  main_goal text,
  stage text,
  created_at timestamptz default now()
);

create table parents (
  id uuid primary key references profiles(id) on delete cascade,
  phone text
);

create table student_parent (
  student_id uuid references students(id) on delete cascade,
  parent_id uuid references parents(id) on delete cascade,
  primary key (student_id, parent_id)
);

-- ---------- Навыки и маршрут ----------

create table skills (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid references teachers(id) on delete cascade,
  name text not null,
  subject text,       -- Математика / Нейропедагогика
  section text,        -- Дроби / Устный счёт ...
  parent_skill_id uuid references skills(id) -- для дерева навыков
);

create table learning_routes (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  created_at timestamptz default now()
);

create table route_steps (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references learning_routes(id) on delete cascade,
  skill_id uuid not null references skills(id),
  status text not null default 'upcoming'
    check (status in ('mastered','forming','weak','repeat','upcoming')),
  pct int default 0,
  attempts int default 0,
  independence int default 0, -- 1..5
  last_check date,
  next_check date,
  comment text,
  sort_order int default 0
);

-- ---------- Диагностика ----------

create table diagnostics (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  block text not null,   -- Математика / Когнитивный
  date date default current_date
);

create table diagnostic_results (
  id uuid primary key default gen_random_uuid(),
  diagnostic_id uuid not null references diagnostics(id) on delete cascade,
  skill_id uuid references skills(id),
  correct int, total int, pct int,
  independence int, hints int, time_spent text,
  error_types text[],
  comment text
);

-- ---------- Занятия / журнал ----------

create table lessons (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  teacher_id uuid not null references teachers(id) on delete cascade,
  scheduled_at timestamptz not null,
  duration_min int default 60,
  format text default 'online',
  topic text,
  status text default 'planned' check (status in ('planned','done','cancelled_student','cancelled_teacher','rescheduled')),
  paid boolean default false
);

create table lesson_results (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references lessons(id) on delete cascade,
  accuracy int,
  independence int,
  self_check boolean,
  hints int,
  error_types text[],
  went_well text,
  needs_work text,
  homework_note text,
  next_step text,
  free_text_note text -- для будущей обработки голосового/текстового отчёта
);

-- ---------- Задания и база заданий ----------

create table tasks (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid references teachers(id) on delete cascade,
  title text not null,
  grade text,
  subject text,
  section text,
  skill_id uuid references skills(id),
  difficulty int check (difficulty between 1 and 5),
  task_type text, -- выбор ответа / числовой ответ / сопоставление / развёрнутый ...
  body text,
  image_url text,
  correct_answer text,
  solution text,
  hint text,
  auto_check_type text check (auto_check_type in ('number','choice','multi_choice','match','sequence','boolean','manual')),
  typical_errors text[],
  cognitive_load text,
  est_time text,
  source text,
  tags text[]
);

create table homework (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  lesson_id uuid references lessons(id),
  title text,
  assigned_date date default current_date,
  due_date date,
  status text default 'pending' check (status in ('pending','review','checked')),
  score int
);

create table assignments ( -- связь ДЗ ↔ конкретные задания
  id uuid primary key default gen_random_uuid(),
  homework_id uuid not null references homework(id) on delete cascade,
  task_id uuid not null references tasks(id)
);

create table assignment_tasks ( -- попытки ученика по каждому заданию
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references assignments(id) on delete cascade,
  status text default 'not_started' check (status in ('not_started','in_progress','submitted','correct','incorrect','needs_review')),
  attempt_count int default 0,
  student_answer text,
  attachment_url text,
  teacher_comment text,
  error_type text
);

create table task_attempts (
  id uuid primary key default gen_random_uuid(),
  assignment_task_id uuid not null references assignment_tasks(id) on delete cascade,
  attempt_number int,
  answer text,
  is_correct boolean,
  created_at timestamptz default now()
);

-- ---------- Абонементы и оплаты ----------

create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  name text,
  total_lessons int,
  used_lessons int default 0,
  price numeric(10,2),
  purchased_at date,
  valid_until date,
  paid boolean default false
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid references subscriptions(id) on delete cascade,
  amount numeric(10,2),
  paid_at date default current_date,
  method text
);

create table attendance (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references lessons(id) on delete cascade,
  status text check (status in ('done','cancelled_student','cancelled_teacher','rescheduled','no_show'))
);

-- ---------- Отчёты и уведомления ----------

create table feedback_reports (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  period_start date,
  period_end date,
  content text,
  sent_at timestamptz
);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid references teachers(id) on delete cascade,
  student_id uuid references students(id) on delete cascade,
  type text, -- hw_missed / hw_low / no_dynamics / checkpoint_due / sub_low / unpaid / feedback_due
  message text,
  is_read boolean default false,
  created_at timestamptz default now()
);

create table teacher_quality (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references lessons(id) on delete cascade,
  goal_set boolean, prepared boolean, level_match boolean,
  errors_analyzed boolean, hw_sent_on_time boolean,
  route_adjusted boolean, checkpoints_respected boolean, parent_feedback boolean
);

create table achievements (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  label text,
  earned_at timestamptz default now()
);

-- ============================================================
-- Row Level Security — каждый видит только своё
-- ============================================================

alter table students enable row level security;
alter table lessons enable row level security;
alter table homework enable row level security;
alter table subscriptions enable row level security;
alter table learning_routes enable row level security;
alter table route_steps enable row level security;
alter table feedback_reports enable row level security;

-- преподаватель видит своих учеников
create policy "teacher sees own students" on students
  for all using (teacher_id = auth.uid());

-- ученик видит только свою карточку
create policy "student sees self" on students
  for select using (profile_id = auth.uid());

-- родитель видит своих детей
create policy "parent sees own children" on students
  for select using (
    id in (select student_id from student_parent where parent_id = auth.uid())
  );

-- аналогичные политики нужно повторить для lessons/homework/subscriptions/
-- learning_routes/route_steps/feedback_reports, связывая их со student_id
-- через students.teacher_id / students.profile_id / student_parent.
-- Пример для homework:
create policy "teacher manages homework" on homework
  for all using (
    student_id in (select id from students where teacher_id = auth.uid())
  );
create policy "student sees own homework" on homework
  for select using (
    student_id in (select id from students where profile_id = auth.uid())
  );
create policy "parent sees child homework" on homework
  for select using (
    student_id in (select student_id from student_parent where parent_id = auth.uid())
  );
