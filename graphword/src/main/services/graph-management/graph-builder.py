import os
import time
from collections import defaultdict


class WordGraphBuilder:
    def __init__(self, input_file, output_file):
        self.input_file = input_file
        self.output_file = output_file
        self.vocabulary = defaultdict(int)
        self.current_word_length = 3 
        self.relations = set()  

    def load_vocabulary(self):
        if not os.path.exists(self.input_file):
            raise FileNotFoundError(f"File not found: {self.input_file}")

        with open(self.input_file, 'r', encoding='utf-8') as vocab_file:
            for line in vocab_file:
                word, count = line.strip().split(':')
                word = word.strip()
                count = int(count.strip())
                self.vocabulary[word] = count

    def one_letter_difference(self, word1, word2):
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
        new_words = [word for word in self.vocabulary if len(word) == self.current_word_length]

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
        os.makedirs(os.path.dirname(self.output_file), exist_ok=True)
        with open(self.output_file, 'w', encoding='utf-8') as graph_file:
            for word1, word2, weight in self.relations:
                graph_file.write(f"{word1} {word2} {weight:.4f}\n")
        print(f"Updated graph saved at: {self.output_file}")

    def expand_graph(self):
        print(f"Processing words of length {self.current_word_length}...")
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
        self.graph_builder = WordGraphBuilder(
            input_file=self.global_vocabulary_file,
            output_file=self.datamart_file
        )

    def execute(self):
        print("Starting incremental graph construction process...")
        self.initialize_graph_builder()
        self.graph_builder.load_vocabulary()

        while True:
            if self.graph_builder.current_word_length > 7:
                print("All words have been processed.")
                break

            self.graph_builder.expand_graph()
            print(f"Waiting 5 seconds before processing the next word length...")
            time.sleep(5)  


if __name__ == "__main__":
    datalake_directory = './datamart_dictionary'
    datamart_file = './datamart_graph/word_graph.txt'

    controller = Controller(datalake_directory, datamart_file)
    controller.execute()