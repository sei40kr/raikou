# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Raikou::ActiveRecordExtension do
  describe '#paginate' do
    context 'given ordering by a single column' do
      context 'given a non-empty dataset' do
        before do
          # Create 25 users for pagination testing
          25.times do |i|
            User.create!(name: "User #{i}", age: 20 + i)
          end
        end

        context 'when paginating forward' do
          context 'when ordering by ASC' do
            it 'then returns records in ascending order' do
              page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
              expect(page.size).to eq(5)
              expect(page.records.map(&:id)).to eq([1, 2, 3, 4, 5])
            end

            it 'then has_next_page is true when more pages exist' do
              page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
              expect(page.has_next_page).to eq(true)
            end

            it 'then has_next_page is false on the last page' do
              page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
              # Navigate to the last page
              last_page = User.order(:id).paginate(per_page: 5, cursor: page.last_cursor,
                                                   direction: Raikou::Direction::Forward)
              while last_page.has_next_page
                last_page = User.order(:id).paginate(per_page: 5, cursor: last_page.last_cursor,
                                                     direction: Raikou::Direction::Forward)
              end
              expect(last_page.has_next_page).to eq(false)
            end

            it 'then has_previous_page is false on the first page' do
              page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
              expect(page.has_previous_page).to eq(false)
            end

            it 'then has_previous_page is true on subsequent pages' do
              page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
              second_page = User.order(:id).paginate(per_page: 5, cursor: page.last_cursor,
                                                     direction: Raikou::Direction::Forward)
              expect(second_page.has_previous_page).to eq(true)
            end

            it 'then first_cursor and last_cursor have correct values' do
              page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
              expect(page.first_cursor).to eq('eyJpZCI6MX0')
              expect(page.last_cursor).to eq('eyJpZCI6NX0')
            end
          end

          context 'when ordering by DESC' do
            it 'then returns records in descending order' do
              page = User.order(id: :desc).paginate(per_page: 5, direction: Raikou::Direction::Forward)
              expect(page.size).to eq(5)
              expect(page.records.map(&:id)).to eq([25, 24, 23, 22, 21])
            end
          end
        end

        context 'when paginating backward' do
          context 'when ordering by ASC' do
            it 'then returns records in ascending order before the cursor' do
              # Get the cursor of the 10th record (last of first page)
              forward_page = User.order(:id).paginate(per_page: 10, direction: Raikou::Direction::Forward)
              cursor = forward_page.last_cursor

              # Paginate backward from the cursor (should get 5 records before the cursor)
              page = User.order(:id).paginate(per_page: 5, cursor: cursor, direction: Raikou::Direction::Backward)
              expect(page.size).to eq(5)
              # Should get records 5-9 (5 records before the 10th)
              expect(page.records.map(&:id)).to eq([5, 6, 7, 8, 9])
            end

            it 'then has_next_page is true when cursor exists' do
              forward_page = User.order(:id).paginate(per_page: 10, direction: Raikou::Direction::Forward)
              cursor = forward_page.last_cursor

              page = User.order(:id).paginate(per_page: 5, cursor: cursor, direction: Raikou::Direction::Backward)
              expect(page.has_next_page).to eq(true)
            end

            it 'then has_previous_page indicates if more backward pages exist' do
              forward_page = User.order(:id).paginate(per_page: 10, direction: Raikou::Direction::Forward)
              cursor = forward_page.last_cursor

              page = User.order(:id).paginate(per_page: 5, cursor: cursor, direction: Raikou::Direction::Backward)
              expect(page.has_previous_page).to eq(true)

              # Paginate backward until the beginning
              while page.has_previous_page
                page = User.order(:id).paginate(per_page: 5, cursor: page.first_cursor,
                                                direction: Raikou::Direction::Backward)
              end
              expect(page.has_previous_page).to eq(false)
            end
          end

          context 'when ordering by DESC' do
            it 'then returns records in descending order before the cursor' do
              forward_page = User.order(id: :desc).paginate(per_page: 10, direction: Raikou::Direction::Forward)
              cursor = forward_page.last_cursor

              page = User.order(id: :desc).paginate(per_page: 5, cursor: cursor, direction: Raikou::Direction::Backward)
              expect(page.size).to eq(5)
              # Should get 5 records before the cursor in descending order
              expect(page.records.map(&:id)).to eq([21, 20, 19, 18, 17])
            end
          end
        end
      end

      context 'given an empty dataset' do
        it 'then returns an empty page with correct metadata' do
          page = User.order(:id).paginate(per_page: 20, direction: Raikou::Direction::Forward)
          expect(page.size).to eq(0)
          expect(page.has_next_page).to eq(false)
          expect(page.has_previous_page).to eq(false)
          expect(page.first_cursor).to be_nil
          expect(page.last_cursor).to be_nil
        end
      end

      context 'given ordering by a column from the primary table' do
        before do
          User.create!(name: 'Alice', age: 25)
          User.create!(name: 'Bob', age: 30)
          User.create!(name: 'Charlie', age: 35)

          # Create posts with user_id column value matching user ages for ordering test
          Post.create!(title: 'Post A', user_id: 25, likes: 10)
          Post.create!(title: 'Post B', user_id: 30, likes: 20)
          Post.create!(title: 'Post C', user_id: 35, likes: 30)
        end

        it 'then returns data correctly when ordered by that column' do
          page = Post.order(user_id: :asc).paginate(per_page: 5, direction: Raikou::Direction::Forward)
          expect(page.size).to eq(3)
          expect(page.records.map(&:title)).to eq(['Post A', 'Post B', 'Post C'])
        end
      end
    end

    context 'given ordering by multiple columns' do
      context 'given different columns from the same table' do
        before do
          Post.create!(title: 'Post A', user_id: 1, likes: 10, created_at: Time.parse('2024-01-01'))
          Post.create!(title: 'Post B', user_id: 2, likes: 20, created_at: Time.parse('2024-01-02'))
          Post.create!(title: 'Post C', user_id: 3, likes: 30, created_at: Time.parse('2024-01-03'))
        end

        it 'then returns data correctly ordered by the specified columns' do
          page = Post.order(likes: :asc, user_id: :asc).paginate(per_page: 5, direction: Raikou::Direction::Forward)
          expect(page.size).to eq(3)
          expect(page.records.map(&:title)).to eq(['Post A', 'Post B', 'Post C'])
        end
      end

      context 'given timestamp columns' do
        before do
          Post.create!(title: 'Post A', user_id: 1, likes: 10, created_at: Time.parse('2024-02-01'),
                       updated_at: Time.parse('2024-03-01'))
          Post.create!(title: 'Post B', user_id: 2, likes: 20, created_at: Time.parse('2024-02-02'),
                       updated_at: Time.parse('2024-03-02'))
          Post.create!(title: 'Post C', user_id: 3, likes: 30, created_at: Time.parse('2024-02-03'),
                       updated_at: Time.parse('2024-03-03'))
        end

        it 'then returns data correctly when ordered by created_at and updated_at' do
          page = Post.order(created_at: :asc, updated_at: :asc).paginate(per_page: 5,
                                                                         direction: Raikou::Direction::Forward)
          expect(page.size).to eq(3)
          expect(page.records.map(&:title)).to eq(['Post A', 'Post B', 'Post C'])
        end
      end

      context 'given records with shared first-column values' do
        before do
          # Create 10 users with age pattern: 20, 20, 20, 30, 30, 30, 40, 40, 40, 50
          # and varying ids to test the boundary conditions
          [20, 20, 20, 30, 30, 30, 40, 40, 40, 50].each_with_index do |age, i|
            User.create!(name: "User #{i}", age: age)
          end
        end

        context 'when paginating forward' do
          context 'when ordering (ASC, ASC)' do
            it 'then correctly handles boundaries where first column values are equal' do
              page = User.order(age: :asc, id: :asc).paginate(per_page: 2, direction: Raikou::Direction::Forward)
              expect(page.size).to eq(2)
              # Age 20 with IDs 1, 2
              expect(page.records.map(&:id)).to eq([1, 2])

              # Navigate to next page (should cross age boundary from 20 to 30)
              second_page = User.order(age: :asc, id: :asc).paginate(per_page: 2, cursor: page.last_cursor,
                                                                     direction: Raikou::Direction::Forward)
              # Age 20 with ID 3, then age 30 with ID 4
              expect(second_page.records.map(&:id)).to eq([3, 4])
            end
          end

          context 'when ordering (ASC, DESC)' do
            it 'then correctly handles boundaries where first column values are equal' do
              page = User.order(age: :asc, id: :desc).paginate(per_page: 2, direction: Raikou::Direction::Forward)
              expect(page.size).to eq(2)
              # Age 20 with IDs descending: 3, 2
              expect(page.records.map(&:id)).to eq([3, 2])

              second_page = User.order(age: :asc, id: :desc).paginate(per_page: 2, cursor: page.last_cursor,
                                                                      direction: Raikou::Direction::Forward)
              # Age 20 with ID 1, then age 30 with ID 6
              expect(second_page.records.map(&:id)).to eq([1, 6])
            end
          end

          context 'when ordering (DESC, ASC)' do
            it 'then correctly handles boundaries where first column values are equal' do
              page = User.order(age: :desc, id: :asc).paginate(per_page: 2, direction: Raikou::Direction::Forward)
              expect(page.size).to eq(2)
              # Age 50 with ID 10, then age 40 with ID 7
              expect(page.records.map(&:id)).to eq([10, 7])

              second_page = User.order(age: :desc, id: :asc).paginate(per_page: 2, cursor: page.last_cursor,
                                                                      direction: Raikou::Direction::Forward)
              # Age 40 with IDs 8, 9
              expect(second_page.records.map(&:id)).to eq([8, 9])
            end
          end

          context 'when ordering (DESC, DESC)' do
            it 'then correctly handles boundaries where first column values are equal' do
              page = User.order(age: :desc, id: :desc).paginate(per_page: 2, direction: Raikou::Direction::Forward)
              expect(page.size).to eq(2)
              # Age 50 with ID 10, then age 40 with ID 9
              expect(page.records.map(&:id)).to eq([10, 9])

              second_page = User.order(age: :desc, id: :desc).paginate(per_page: 2, cursor: page.last_cursor,
                                                                       direction: Raikou::Direction::Forward)
              # Age 40 with IDs 8, 7
              expect(second_page.records.map(&:id)).to eq([8, 7])
            end
          end
        end

        context 'when paginating backward' do
          context 'when ordering (ASC, ASC)' do
            it 'then correctly handles boundaries where first column values are equal' do
              forward_page = User.order(age: :asc, id: :asc).paginate(per_page: 5,
                                                                      direction: Raikou::Direction::Forward)
              cursor = forward_page.last_cursor

              page = User.order(age: :asc, id: :asc).paginate(per_page: 2, cursor: cursor,
                                                              direction: Raikou::Direction::Backward)
              expect(page.size).to eq(2)
              # Should get 2 records before the 5th record (records at offset 2-3)
              # IDs 3 and 4
              expect(page.records.map(&:id)).to eq([3, 4])
            end
          end

          context 'when ordering (ASC, DESC)' do
            it 'then correctly handles boundaries where first column values are equal' do
              forward_page = User.order(age: :asc, id: :desc).paginate(per_page: 5,
                                                                       direction: Raikou::Direction::Forward)
              cursor = forward_page.last_cursor

              page = User.order(age: :asc, id: :desc).paginate(per_page: 2, cursor: cursor,
                                                               direction: Raikou::Direction::Backward)
              expect(page.size).to eq(2)
              # Should get 2 records before the 5th record (records at offset 2-3)
              # IDs 1 and 6
              expect(page.records.map(&:id)).to eq([1, 6])
            end
          end

          context 'when ordering (DESC, ASC)' do
            it 'then correctly handles boundaries where first column values are equal' do
              forward_page = User.order(age: :desc, id: :asc).paginate(per_page: 5,
                                                                       direction: Raikou::Direction::Forward)
              cursor = forward_page.last_cursor

              page = User.order(age: :desc, id: :asc).paginate(per_page: 2, cursor: cursor,
                                                               direction: Raikou::Direction::Backward)
              expect(page.size).to eq(2)
              # Should get 2 records before the 5th record (records at offset 2-3)
              # IDs 8 and 9
              expect(page.records.map(&:id)).to eq([8, 9])
            end
          end

          context 'when ordering (DESC, DESC)' do
            it 'then correctly handles boundaries where first column values are equal' do
              forward_page = User.order(age: :desc, id: :desc).paginate(per_page: 5,
                                                                        direction: Raikou::Direction::Forward)
              cursor = forward_page.last_cursor

              page = User.order(age: :desc, id: :desc).paginate(per_page: 2, cursor: cursor,
                                                                direction: Raikou::Direction::Backward)
              expect(page.size).to eq(2)
              # Should get 2 records before the 5th record (records at offset 2-3)
              # IDs 8 and 7
              expect(page.records.map(&:id)).to eq([8, 7])
            end
          end
        end
      end
    end

    context 'given edge cases and error handling scenarios' do
      context 'when no order is specified' do
        it 'then raises InvalidOrderError' do
          expect do
            User.all.paginate(per_page: 5,
                              direction: Raikou::Direction::Forward)
          end.to raise_error(Raikou::InvalidOrderError, /Order must be specified/)
        end
      end

      context 'when an invalid cursor is provided' do
        it 'then raises InvalidCursorError' do
          expect do
            User.order(:id).paginate(per_page: 5, cursor: 'invalid-cursor', direction: Raikou::Direction::Forward)
          end
            .to raise_error(Raikou::InvalidCursorError, /Invalid cursor format/)
        end
      end

      context 'when using different per_page values across requests' do
        before do
          10.times { |i| User.create!(name: "User #{i}", age: 20 + i) }
        end

        it 'then still paginates correctly with different per_page values' do
          page1 = User.order(:id).paginate(per_page: 3, direction: Raikou::Direction::Forward)
          expect(page1.size).to eq(3)

          # Use cursor from per_page=3 with per_page=5
          page2 = User.order(:id).paginate(per_page: 5, cursor: page1.last_cursor,
                                           direction: Raikou::Direction::Forward)
          expect(page2.size).to eq(5)
          # Should start after the 3rd record
          expect(page2.records.map(&:id)).to eq([4, 5, 6, 7, 8])
        end
      end

      context 'when using unsupported order format (String literal)' do
        it 'then raises InvalidOrderError' do
          expect { User.order('id ASC').paginate(per_page: 5, direction: Raikou::Direction::Forward) }
            .to raise_error(Raikou::InvalidOrderError, /Unsupported order format/)
        end
      end

      context 'when the record referenced by cursor has been deleted' do
        before do
          15.times { |i| User.create!(name: "User #{i}", age: 20 + i) }
        end

        it 'then still paginates correctly based on cursor values' do
          # Get first page
          first_page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
          expect(first_page.size).to eq(5)
          cursor = first_page.last_cursor

          # Delete the record that the cursor points to (5th record)
          fifth_user = User.order(:id).limit(5).last
          fifth_user.destroy

          # Paginate forward with the cursor
          # Should return records after the deleted record's position
          second_page = User.order(:id).paginate(per_page: 5, cursor: cursor, direction: Raikou::Direction::Forward)

          # The cursor contains id=5, so we should get records with id > 5
          # Since id=5 was deleted, we should get ids 6, 7, 8, 9, 10
          expect(second_page.records.map(&:id)).to eq([6, 7, 8, 9, 10])
          expect(second_page.size).to eq(5)
        end

        it 'then backward pagination works correctly when cursor record is deleted' do
          # Get a page in the middle
          first_page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
          second_page = User.order(:id).paginate(per_page: 5, cursor: first_page.last_cursor,
                                                 direction: Raikou::Direction::Forward)
          cursor = second_page.last_cursor

          # Save the ID from cursor before deleting
          cursor_record_id = User.order(:id).offset(9).limit(1).first.id

          # Delete the record at cursor position (10th record)
          tenth_user = User.order(:id).offset(9).limit(1).first
          tenth_user.destroy

          # Paginate backward with the cursor
          # The cursor still contains the deleted record's id value
          backward_page = User.order(:id).paginate(per_page: 3, cursor: cursor, direction: Raikou::Direction::Backward)

          # Should get 3 records before the cursor's id value (id < 10)
          # Records 1-9 exist, last 3 before cursor are: 7, 8, 9
          expect(backward_page.records.map(&:id)).to eq([7, 8, 9])
          expect(backward_page.size).to eq(3)
        end
      end

      context 'when per_page has invalid values' do
        before do
          10.times { |i| User.create!(name: "User #{i}", age: 20 + i) }
        end

        context 'when per_page is zero' do
          it 'then returns an empty page' do
            page = User.order(:id).paginate(per_page: 0, direction: Raikou::Direction::Forward)
            expect(page.size).to eq(0)
            expect(page.records).to be_empty
            # With per_page=0, we fetch 1 record (0+1) to check has_next_page
            # Since there are records, has_next_page should be false (we got 0 requested)
            expect(page.has_next_page).to eq(true) # There's actually one more record
          end
        end

        context 'when per_page is negative' do
          it 'then raises ArgumentError' do
            # Array#take raises ArgumentError for negative size
            expect { User.order(:id).paginate(per_page: -1, direction: Raikou::Direction::Forward) }
              .to raise_error(ArgumentError, /attempt to take negative size/)
          end
        end

        context 'when per_page is extremely large' do
          it 'then returns all available records' do
            page = User.order(:id).paginate(per_page: 10_000, direction: Raikou::Direction::Forward)
            expect(page.size).to eq(10) # Only 10 records exist
            expect(page.has_next_page).to eq(false)
            expect(page.has_previous_page).to eq(false)
          end
        end
      end

      context 'when total records equals per_page exactly' do
        before do
          # Create exactly 5 records
          5.times { |i| User.create!(name: "User #{i}", age: 20 + i) }
        end

        it 'then has_next_page is false' do
          page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
          expect(page.size).to eq(5)
          expect(page.has_next_page).to eq(false)
        end

        it 'then has_previous_page is false' do
          page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
          expect(page.has_previous_page).to eq(false)
        end
      end

      context 'when total records is one more than per_page' do
        before do
          # Create exactly 6 records (5 + 1)
          6.times { |i| User.create!(name: "User #{i}", age: 20 + i) }
        end

        it 'then first page has_next_page is true' do
          page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
          expect(page.size).to eq(5)
          expect(page.has_next_page).to eq(true)
        end

        it 'then second page has exactly one record' do
          first_page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
          second_page = User.order(:id).paginate(per_page: 5, cursor: first_page.last_cursor,
                                                 direction: Raikou::Direction::Forward)
          expect(second_page.size).to eq(1)
          expect(second_page.has_next_page).to eq(false)
        end

        it 'then second page has_previous_page is true' do
          first_page = User.order(:id).paginate(per_page: 5, direction: Raikou::Direction::Forward)
          second_page = User.order(:id).paginate(per_page: 5, cursor: first_page.last_cursor,
                                                 direction: Raikou::Direction::Forward)
          expect(second_page.has_previous_page).to eq(true)
        end
      end
    end
  end
end
