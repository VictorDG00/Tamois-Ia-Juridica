class CreateAnalysisFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_feedbacks do |t|
      t.references :analysis, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :section
      t.integer :item_index
      t.string :verdict
      t.text :comment
      t.text :item_snapshot

      t.timestamps
    end
  end
end
