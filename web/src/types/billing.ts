export type OrderStatus = 'pending' | 'approved' | 'rejected' | 'refunded'

export interface Order {
  id: string
  status: OrderStatus
  product_type: 'course' | 'career'
  product_id: string
  product_title: string
  product_slug: string
  amount_cents: number
  currency: string
  provider: string
  created_at: string
}

export interface CreateOrderResponse {
  order: Order
  checkout_url: string
}
