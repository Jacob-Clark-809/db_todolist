require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger
  end

  def find_list(id)
    sql = <<~SQL
      SELECT lists.*,
      count(todos.id) AS todos_count,
      count(nullif(todos.completed, true)) AS todos_remaining_count
      FROM lists LEFT JOIN todos
      ON todos.list_id = lists.id
      WHERE lists.id = $1
      GROUP BY lists.id
      ORDER BY lists.name
    SQL
    result = query(sql, id)

    tuple_to_list_hash(result.first)
  end

  def all_lists
    sql = <<~SQL
      SELECT lists.*,
      count(todos.id) AS todos_count,
      count(nullif(todos.completed, true)) AS todos_remaining_count
      FROM lists LEFT JOIN todos
      ON todos.list_id = lists.id
      GROUP BY lists.id
      ORDER BY lists.name
    SQL
    result = query(sql)

    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

  def create_new_list(name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, name)
  end

  def update_list_name(id, name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, name, id)
  end

  def delete_list(id)
    sql = "DELETE FROM lists WHERE id = $1"
    query(sql, id)
  end

  def create_new_todo(list_id, name)
    sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2)"
    query(sql, name, list_id)
  end

  def delete_todo(list_id, todo_id)
    sql = "DELETE FROM todos WHERE id = $1 AND list_id = $2"
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $1 WHERE id = $2 AND list_id = $3"
    query(sql, new_status, todo_id, list_id)
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1"
    query(sql, list_id)
  end

  def disconnect
    @db.close
  end

  def find_todos_for_list(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1"
    result = query(sql, list_id)

    result.map do |tuple|
      completed = tuple["completed"] == "t"
      { id: tuple["id"], name: tuple["name"], completed: completed }
    end
  end

  private

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def tuple_to_list_hash(tuple)
    { id: tuple["id"].to_i,
      name: tuple["name"],
      todos_count: tuple["todos_count"].to_i,
      todos_remaining_count: tuple["todos_remaining_count"].to_i }
  end
end
