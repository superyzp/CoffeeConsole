Schema = mongoose.Schema
ObjectId = Schema.ObjectId

TicketSchema = new Schema({
    name: String
    actionTime: Date
    seat: String
    price: Number
    createAt: Date
    updateAt: Date
    deltedAt: Date
  },
  strict: false
)

#删除已有的models，使其可以重入
delete mongoose.models["ticket"]
Ticket = mongoose.model "ticket", TicketSchema

module.exports = Ticket
