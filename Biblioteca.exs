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


defmodule Biblioteca do
  @aforo_maximo 5
  @capacidad_estante 3

  @estudiantes [
    {"Ana", 0},
    {"Luis", 1500},
    {"Sofía", 1650},
    {"Mateo", 1800},
    {"Valentina", 1950},
    {"Camilo", 2100},
    {"Laura", 2250},
    {"Andrés", 2400}
  ]

  @libros_marta ["Cien años de soledad", "Los juegos del hambre", "María", "El Quijote"]
  @libros_pedro ["Rayuela", "Pedro Páramo", "Ficciones", "La odisea"]

  def main do
    Util.mostrar_mensaje("Abriendo la biblioteca... proceso principal: #{inspect(self())}\n")
    principal_pid = self()

    aforo = Semaforo.crear("aforo", @aforo_maximo, true)
    espacios = Semaforo.crear("espacios", @capacidad_estante)
    libros = Semaforo.crear("libros", 0)
    mutex = Semaforo.crear("mutex", 1)
    estante = Estante.crear(@capacidad_estante)

    semaforos_estante = {espacios, libros, mutex}

    spawn(fn ->
      bibliotecario("Marta", @libros_marta, estante, semaforos_estante, principal_pid)
    end)

    spawn(fn ->
      bibliotecario("Pedro", @libros_pedro, estante, semaforos_estante, principal_pid)
    end)

    Enum.each(@estudiantes, fn {nombre, llegada} ->
      spawn(fn ->
        Process.sleep(llegada)
        estudiante(nombre, aforo, estante, semaforos_estante, principal_pid)
      end)
    end)

    procesos_pendientes = 2 + length(@estudiantes)
    esperar_procesos(procesos_pendientes)

    Enum.each([aforo, espacios, libros, mutex], &Semaforo.detener/1)
    Estante.detener(estante)

    Util.mostrar_mensaje("\nTodos terminaron. La biblioteca cierra sus puertas.")
  end


  #productor
  def bibliotecario(nombre, lista_libros, estante, {espacios, libros, mutex}, principal_pid) do
    Util.mostrar_mensaje("Bibliotecario #{nombre} empieza a trabajar: #{inspect(self())}")

    Enum.each(lista_libros, fn libro ->
      Process.sleep(Enum.random(200..500)) 
   
      Semaforo.wait(espacios, "#{nombre} ESPERA: el estante está lleno")
      Semaforo.wait(mutex)      

      Util.mostrar_mensaje("#{nombre} coloca \"#{libro}\" en el estante")
      Estante.poner(estante, libro)

      Semaforo.signal(mutex) 
    end)

    send(principal_pid, {:bibliotecario_finalizado, nombre})
  end

  #consumidor
  def estudiante(nombre, aforo, estante, {espacios, libros, mutex}, principal_pid) do
    Util.mostrar_mensaje("#{nombre} llega a la biblioteca: #{inspect(self())}")

    Semaforo.wait(aforo, "#{nombre} ESPERA afuera: la biblioteca está llena")
    Util.mostrar_mensaje("#{nombre} ENTRA a la biblioteca")

    Semaforo.wait(libros, "#{nombre} ESPERA: el estante está vacío")
    Semaforo.wait(mutex) 

    libro = Estante.tomar(estante)
    Util.mostrar_mensaje("#{nombre} toma \"#{libro}\"")

    Semaforo.signal(mutex)
    Semaforo.signal(espacios)

    Process.sleep(Enum.random(1500..3000))

    Util.mostrar_mensaje("#{nombre} termina de leer y SALE")
    Semaforo.signal(aforo)

    send(principal_pid, {:estudiante_finalizado, nombre, libro})
  end


  #Llamada recursiva para recibir mensajes solo hasta que todos los procesos hayan terminado
  defp esperar_procesos(0), do: :ok

  defp esperar_procesos(pendientes) do
    receive do
      {:bibliotecario_finalizado, nombre} ->
        Util.mostrar_mensaje(" Principal: #{nombre} terminó de colocar sus libros")

      {:estudiante_finalizado, nombre, libro} ->
        Util.mostrar_mensaje("Principal: #{nombre} terminó y leyó \"#{libro}\"")
    end

    esperar_procesos(pendientes - 1)
  end
end

Biblioteca.main()

