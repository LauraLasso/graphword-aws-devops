import os
import time
from collections import defaultdict


class WordGraphBuilder:
    def __init__(self, input_file, output_file):
        self.input_file = input_file
        self.output_file = output_file
        self.vocabulary = defaultdict(int)
        self.current_word_length = 3  # Comienza con palabras de 3 letras
        self.relations = set()  # Relaciones acumuladas en el grafo

    def load_vocabulary(self):
        """Carga el vocabulario desde el archivo global_vocabulary.txt."""
        if not os.path.exists(self.input_file):
            raise FileNotFoundError(f"Archivo no encontrado: {self.input_file}")

        with open(self.input_file, 'r', encoding='utf-8') as vocab_file:
            for line in vocab_file:
                word, count = line.strip().split(':')
                word = word.strip()
                count = int(count.strip())
                self.vocabulary[word] = count

    def one_letter_difference(self, word1, word2):
        """Devuelve True si word1 y word2 difieren en exactamente una letra."""
        # if len(word1) != len(word2):
        #     return False

        # Asi evitamos que no coga palabras de menos de 3 letras
        if len(word1)<3 or len(word2)<3:
            return False
        
        diff_count = 0
        for c1, c2 in zip(word1, word2):
            if c1 != c2:
                diff_count += 1
                if diff_count > 1:
                    return False
        return diff_count == 1

    def build_incremental_graph(self):
        """Construye relaciones incrementales para la longitud actual de palabras."""
        new_words = [word for word in self.vocabulary if len(word) == self.current_word_length]

        # Relacionar palabras nuevas entre sí
        for i, word1 in enumerate(new_words):
            for word2 in new_words[i + 1:]:
                if self.one_letter_difference(word1, word2):
                    count_word1 = self.vocabulary[word1]
                    count_word2 = self.vocabulary[word2]
                    if count_word2 != 0:
                        weight = count_word1 / count_word2
                        inverse_weight = count_word2 / count_word1
                        self.relations.add((word1, word2, weight))
                        self.relations.add((word2, word1, inverse_weight))

        # Relacionar palabras nuevas con palabras existentes de diferentes longitudes
        existing_words = [word for word in self.vocabulary if len(word) < self.current_word_length]
        for word1 in new_words:
            for word2 in existing_words:
                if self.one_letter_difference(word1, word2):
                    count_word1 = self.vocabulary[word1]
                    count_word2 = self.vocabulary[word2]
                    if count_word2 != 0:
                        weight = count_word1 / count_word2
                        inverse_weight = count_word2 / count_word1
                        self.relations.add((word1, word2, weight))
                        self.relations.add((word2, word1, inverse_weight))

    def save_graph(self):
        """Guarda todas las relaciones en el archivo."""
        os.makedirs(os.path.dirname(self.output_file), exist_ok=True)
        with open(self.output_file, 'w', encoding='utf-8') as graph_file:
            for word1, word2, weight in self.relations:
                graph_file.write(f"{word1} {word2} {weight:.4f}\n")
        print(f"Grafo actualizado guardado en: {self.output_file}")

    def expand_graph(self):
        """Expande el grafo añadiendo palabras de la longitud actual."""
        print(f"Procesando palabras de longitud {self.current_word_length}...")
        self.build_incremental_graph()
        self.save_graph()
        self.current_word_length += 1


class Controller:
    def __init__(self, datalake_directory, datamart_file):
        self.datalake_directory = datalake_directory
        self.datamart_file = datamart_file
        self.graph_builder = None
        self.global_vocabulary_file = os.path.join(datalake_directory, 'global_vocabulary.txt')

    def initialize_graph_builder(self):
        """Inicializa el constructor de grafos."""
        self.graph_builder = WordGraphBuilder(
            input_file=self.global_vocabulary_file,
            output_file=self.datamart_file
        )

    def execute(self):
        """Expande el grafo progresivamente cada 5 minutos."""
        print("Iniciando proceso de construcción incremental del grafo...")
        self.initialize_graph_builder()
        self.graph_builder.load_vocabulary()

        # Expandir grafo hasta que no haya más palabras de longitud mayor
        while True:
            #if self.graph_builder.current_word_length > max(len(word) for word in self.graph_builder.vocabulary):
            if self.graph_builder.current_word_length > 7:
                print("Todas las palabras han sido procesadas.")
                break

            self.graph_builder.expand_graph()
            print(f"Esperando 5 segundos antes de procesar la siguiente longitud...")
            time.sleep(5)  # Espera 5 minutos=300


if __name__ == "__main__":
    # Parámetros para la ejecución
    datalake_directory = './datamart_dictionary'
    datamart_file = './datamart_graph/word_graph.txt'

    # Crear y ejecutar el controller
    controller = Controller(datalake_directory, datamart_file)
    controller.execute()