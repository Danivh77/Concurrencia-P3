defmodule Util do

  # Muestra un mensaje en consola.
  def mostrar_mensaje(mensaje) do
    IO.puts(mensaje)
  end

  # Muestra un mensaje usando el programa Java "Mensaje".
  def mostrar_mensaje_java(mensaje) do
    System.cmd("java", ["-cp", ".", "Mensaje", mensaje])
  end

  # Muestra un mensaje en la salida de error.
  def mostrar_error(mensaje) do
    IO.puts(:stderr, mensaje)
  end

  # Convierte un número a texto con 1 decimal, sin notación científica.
  def formatear(numero) do
    :erlang.float_to_binary(numero / 1, decimals: 1)
  end

  # ingresar/2: pide un dato y lo convierte según el tipo (pattern matching).

  # Devuelve el texto ingresado sin espacios al inicio/final.
  def ingresar(mensaje, :texto) do
    mensaje
    |> IO.gets()
    |> String.trim()
  end

  # Devuelve true con "si"/"s", false con "no"/"n". Si no, vuelve a preguntar.
  def ingresar(mensaje, :booleano) do
    respuesta =
      mensaje
      |> ingresar(:texto)
      |> String.downcase()

    cond do
      respuesta in ["si", "sí", "s"] -> true
      respuesta in ["no", "n"] -> false
      true ->
        mostrar_error("Error, responda 'si' o 'no'")
        ingresar(mensaje, :booleano)
    end
  end

  # Devuelve un entero. Si el dato no es válido, vuelve a preguntar.
  def ingresar(mensaje, :entero) do
    ingresar_numero(mensaje, &Integer.parse/1, "entero")
  end

  # Devuelve un real. Si el dato no es válido, vuelve a preguntar.
  def ingresar(mensaje, :real) do
    ingresar_numero(mensaje, &Float.parse/1, "real")
  end

  # Auxiliar: convierte el texto con el parser dado; solo acepta si no sobra nada.
  defp ingresar_numero(mensaje, parser, nombre_tipo) do
    case parser.(ingresar(mensaje, :texto)) do
      {numero, ""} ->
        numero

      _ ->
        mostrar_error("Error, se espera que ingrese un número #{nombre_tipo}")
        ingresar_numero(mensaje, parser, nombre_tipo)
    end
  end
end
