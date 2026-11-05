defmodule Semaforo do
  @moduledoc """
Módulo principal del programa de simulación de una biblioteca con semáforos y productor-consumidor.
-versión 1.0
-autoras: Laura Daniela Vega Herrera, Elizabeth Cuellar Vélez
-fecha: 2026-11-05
"""

  def crear(nombre, valor_inicial, mostrar_estado \\ false) do
    spawn(fn -> loop(nombre, valor_inicial, [], mostrar_estado) end)
  end

  def wait(semaforo, mensaje_espera \\ nil) do
    send(semaforo, {:wait, self()})

    receive do
      {:permiso_concedido, ^semaforo} ->
        :ok

      {:debes_esperar, ^semaforo} ->
        if mensaje_espera, do: Util.mostrar_mensaje(mensaje_espera)

        receive do
          {:permiso_concedido, ^semaforo} -> :ok
        end
    end
  end

  def signal(semaforo) do
    send(semaforo, :signal)
  end

  def detener(semaforo) do
    send(semaforo, :detener)
  end

  defp loop(nombre, permisos, cola, mostrar_estado) do
    receive do
      {:wait, pid} when permisos > 0 ->
        mostrar(nombre, permisos - 1, cola, mostrar_estado)
        send(pid, {:permiso_concedido, self()})
        loop(nombre, permisos - 1, cola, mostrar_estado)

      {:wait, pid} ->
        nueva_cola = cola ++ [pid]
        mostrar(nombre, permisos, nueva_cola, mostrar_estado)
        send(pid, {:debes_esperar, self()})
        loop(nombre, permisos, nueva_cola, mostrar_estado)

      :signal when cola == [] ->
        mostrar(nombre, permisos + 1, cola, mostrar_estado)
        loop(nombre, permisos + 1, cola, mostrar_estado)

      :signal ->
        [siguiente | resto] = cola
        mostrar(nombre, permisos, resto, mostrar_estado)
        send(siguiente, {:permiso_concedido, self()})
        loop(nombre, permisos, resto, mostrar_estado)

      :detener ->
        :ok
    end
  end

  defp mostrar(nombre, permisos, cola, true) do
    Util.mostrar_mensaje("    [Semáforo #{nombre}] permisos libres: #{permisos} | en espera: #{length(cola)}")
  end

  defp mostrar(_nombre, _permisos, _cola, false), do: :ok
end

defmodule Estante do

  def crear(capacidad) do
    spawn(fn -> loop([], capacidad) end)
  end

  def poner(estante, libro) do
    send(estante, {:poner, libro, self()})

    receive do
      :libro_colocado -> :ok
    end
  end

  def tomar(estante) do
    send(estante, {:tomar, self()})

    receive do
      {:libro, libro} -> libro
    end
  end

  def detener(estante) do
    send(estante, :detener)
  end

  defp loop(libros, capacidad) do
    receive do
      {:poner, libro, pid} ->
        nuevos_libros = libros ++ [libro]
        mostrar(nuevos_libros, capacidad)
        send(pid, :libro_colocado)
        loop(nuevos_libros, capacidad)

      {:tomar, pid} ->
        [libro | resto] = libros
        mostrar(resto, capacidad)
        send(pid, {:libro, libro})
        loop(resto, capacidad)

      :detener ->
        :ok
    end
  end

  defp mostrar(libros, capacidad) do
    Util.mostrar_mensaje("    [Estante #{length(libros)}/#{capacidad}] #{inspect(libros)}")
  end
end
