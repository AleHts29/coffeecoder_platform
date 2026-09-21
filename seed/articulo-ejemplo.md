Una goroutine que necesita pasarle un dato a otra tiene dos caminos:
compartir una variable y protegerla con un mutex, o mandarle el dato por
un **channel**. Go empuja hacia el segundo, y lo resume en una frase:
no te comuniques compartiendo memoria; compartí memoria comunicándote.

## Enviar y recibir

Un channel se crea con `make` y se usa con el operador `<-`:

```go
ch := make(chan int)

go func() {
    ch <- 42 // enviar
}()

v := <-ch // recibir
fmt.Println(v)
```

Lo importante no es la sintaxis sino lo que pasa en el tiempo: en un
channel sin buffer, **enviar bloquea** hasta que otra goroutine reciba.
Es un pasamanos: el emisor no suelta el valor hasta que alguien lo agarra.

## El buffer como amortiguador

Si al crear el channel le das una capacidad, el emisor puede dejar
valores sin esperar, hasta llenar el buffer:

```go
ch := make(chan int, 2) // entran 2 valores sin bloquear
```

Probalo: con "Sin buffer", mandá dos valores seguidos. Después pasá a
"Buffer de 2" y repetí.

::demo[channels-buffer]

Fijate en tres cosas:

- Sin buffer, el primer envío ya bloquea al emisor.
- Con buffer de 2, los dos primeros envíos siguen de largo y recién el
  tercero bloquea.
- Recibir de un channel vacío bloquea al receptor, tenga buffer o no.

Un buffer no hace a tu programa más rápido por sí solo: desacopla el
ritmo del emisor y del receptor. Si el receptor es más lento siempre,
el buffer se llena y volvés a estar bloqueado, solo que un poco más tarde.
