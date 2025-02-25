class CreateMessages < ActiveRecord::Migration[5.2]
  def change
    create_table :messages do |t|
      t.string :subject, null: false
      t.text :message
      t.boolean :read, default: false
      t.belongs_to :from,  index: true
      t.belongs_to :to,  index: true
      t.timestamp  :sent_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.boolean :deleted, default: false
      t.timestamp :deleted_at
    end
  end
end
