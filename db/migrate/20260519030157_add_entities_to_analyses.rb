class AddEntitiesToAnalyses < ActiveRecord::Migration[8.1]
  def change
    add_column :analyses, :entities_json, :text
  end
end
